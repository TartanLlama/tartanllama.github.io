---
layout:     post
title:      "Custom Alias Analysis in LLVM"
category:   llvm
tags:
 - llvm
---

At [Codeplay](https://codeplay.com/) I currently work on a compiler backend for an embedded [accelerator](https://en.wikipedia.org/wiki/Hardware_acceleration). The *backend* is the part of the compiler which takes some representation of the source code and translates it to machine code. In my case I'm working with [LLVM](https://llvm.org/), so this representation is [LLVM IR](https://llvm.org/docs/LangRef.html).

It's very common for accelerators like GPUs to have multiple regions of addressable memory -- each with distinct properties. One important optimisation I've implemented recently is extending LLVM's alias analysis functionality to handle the different address spaces for our target architecture.

This article will give an overview of the aim of alias analysis -- along with an example based around address spaces -- and show how custom alias analyses can be expressed in LLVM. You should be able to understand this article even if you don't work with compilers or LLVM; hopefully it gives some insight into what compiler developers do to make the tools you use generate better code. LLVM developers may find the implementation section helpful, but may want to read the [documentation](https://llvm.org/docs/AliasAnalysis.html) or examples linked at the bottom for more details.

## What is alias analysis

Alias analysis is the process of determining whether two pointers can point to the same object (alias) or not. This is very important for some valuable optimisations.

Take this C function as an example:

{% highlight cpp %}
int foo (int __attribute__((address_space(0)))* a,
         int __attribute__((address_space(1)))* b) {
    *a = 42;
    *b = 20;
    return *a;
}
{% endhighlight %}

Those `__attribute__`s specify that `a` points to an `int` in address space `0`, `b` points to an `int` in address space `1`. An important detail of the target architecture for this code is that address spaces `0` and `1` are completely distinct: modifying memory in address space `0` can _never_ affect memory in address space `1`. Here's some LLVM IR which could be generated from this function:

{% highlight llvm %}
define i32 @foo(i32 addrspace(0)* %a, i32 addrspace(1)* %b) #0 {
entry:
  store i32 42, i32 addrspace(0)* %a, align 4
  store i32 20, i32 addrspace(1)* %b, align 4
  %0 = load i32, i32* %a, align 4
  ret i32 %0
}
{% endhighlight %}

For those unfamiliar with LLVM IR, the first `store` is storing `42` into `*a`, the second storing `20` into `*b`. The `%0 = ...` line is like loading `*a` into a temporary variable, which is then returned in the final line.

### Optimising `foo`

Now we want `foo` to be optimised. Can you see an optimisation which could be made?

What we really want is for that load from `a` (the line beginning `%0 = ...`) to be removed and for the final statement to instead return `42`. We want the optimised code to look like this:

{% highlight llvm %}
define i32 @foo(i32 addrspace(0)* %a, i32 addrspace(1)* %b) #0 {
entry:
  store i32 42, i32 addrspace(0)* %a, align 4
  store i32 20, i32 addrspace(1)* %b, align 4
  ret i32 42
}
{% endhighlight %}

However, we have to be very careful, because this optimisation is *only* valid if `a` and `b` do not alias, i.e. they must not point at the same object. Forgetting about the address spaces for a second, consider this call to `foo` where we pass pointers which *do* alias:

{% highlight cpp %}
int i = 0;
int result = foo(&i, &i);
{% endhighlight %}

Inside the unoptimised version of `foo`, `i` will be set to `42`, then to `20`, then `20` will be returned. However, if we carry out desired optimisation then the two stores will occur, but `42` will be returned instead of `20`. We've just broken the behaviour of our function.

The only way that a compiler can reasonably carry out the above optimisation is if it can *prove* that the two pointers cannot possibly alias. This reasoning is carried out through *alias analysis*.

## Custom alias analysis in LLVM

As I mentioned above, address spaces `0` and `1` for our target architecture are distinct. However, this may not hold for some systems, so LLVM cannot assume that it holds in general: we need to make it explicit.

One way to achieve this is [`llvm::AAResultBase`](http://llvm.org/doxygen/classllvm_1_1AAResultBase.html). If our target is called `TAR` then we can create a class called `TARAAResult` which inherits from `AAResultBase<TARAAResult>`[^1]:

[^1]: This pattern of inheriting from a class and passing the derived class as a template argument is known as the [Curiously Recurring Template Pattern](https://www.fluentcpp.com/2017/05/12/curiously-recurring-template-pattern/).

{% highlight cpp %}
class TARAAResult : public AAResultBase<TARAAResult> {
public:
  explicit TARAAResult() : AAResultBase() {}
  TARAAResult(TARAAResult &&Arg) : AAResultBase(std::move(Arg)) {}

  AliasResult alias(const MemoryLocation &LocA, const MemoryLocation &LocB);
};
{% endhighlight %}

The magic happens in the `alias` member function, which takes two [`MemoryLocation`](http://llvm.org/doxygen/classllvm_1_1MemoryLocation.html)s and returns an [`AliasResult`](http://llvm.org/doxygen/namespacellvm.html#ae1738272abcf2ac638b97e7dc6360cfd). The result indicates whether the locations can never alias, may alias, partially alias, or precisely alias. We want our analysis to say "If the address spaces for the two memory locations are different, then they can never alias". The resulting code is surprisingly close to this English description:

{% highlight cpp %}
AliasResult TARAAResult::alias(const MemoryLocation &LocA,
                               const MemoryLocation &LocB) {
  auto AsA = LocA.Ptr->getType()->getPointerAddressSpace();
  auto AsB = LocB.Ptr->getType()->getPointerAddressSpace();

  if (AsA != AsB) {
    return NoAlias;
  }

  // Forward the query to the next analysis.
  return AAResultBase::alias(LocA, LocB);
}
{% endhighlight %}

Alongside this you need a bunch of boilerplate for creating a pass out of this analysis (I'll link to a full example at the end), but after that's done you just register the pass and ensure that the results of it are tracked:

{% highlight cpp %}
void TARPassConfig::addIRPasses() {
  addPass(createTARAAWrapperPass());
  auto AnalysisCallback = [](Pass &P, Function &, AAResults &AAR) {
    if (auto *WrapperPass = P.getAnalysisIfAvailable<TARAAWrapper>()) {
      AAR.addAAResult(WrapperPass->getResult());
    }
  }; 
  addPass(createExternalAAWrapperPass(AnalysisCallback));
  TargetPassConfig::addIRPasses();
}
{% endhighlight %}

We also want to ensure that there is an optimisation pass which will remove unnecessary loads and stores which our new analysis will find. One example is [Global Value Numbering](http://llvm.org/doxygen/NewGVN_8cpp.html).

{% highlight cpp %}
  addPass(createNewGVNPass());
{% endhighlight %}  

After all this is done, running the optimiser on the LLVM IR from the start of the post will eliminate the unnecessary load, and the generated code will be faster as a result.

You can see an example with all of the necessary boilerplate in [LLVM's test suite](https://github.com/llvm-mirror/llvm/blob/master/unittests/Analysis/AliasAnalysisTest.cpp). The AMDGPU target has [a full implementation](http://llvm.org/doxygen/AMDGPUAliasAnalysis_8h_source.html) which is essentially what I presented above extended for more address spaces.

Hopefully you have got a taste of what alias analysis does and the kinds of work involved in writing compilers, even if I have not gone into a whole lot of detail. I may write some more short posts on other areas of compiler development if readers find this interesting. Let me know on [Twitter](https://twitter.com/TartanLlama) or in the comments!

----------
