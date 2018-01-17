---
layout:     post
title:      "Custom Alias Analysis in LLVM"
category:   c++
tags:
 - c++
 - c++17
---

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

{% highlight cpp %}
  addPass(createTARAAWrapperPass());
  addPass(createExternalAAWrapperPass([](Pass &P, Function &, AAResults &AAR) {
              if (auto *WrapperPass = P.getAnalysisIfAvailable<TARAAWrapper>()) {
      AAR.addAAResult(WrapperPass->getResult());
              }
  }));
{% endhighlight %}
