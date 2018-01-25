---
layout:     post
title:      "Do compilers take inline as a hint?"
category:   c++
tags:
 - c++
---

If you've spent any time in C or C++ communities online, you've probably seen someone say this:

> `inline` used to be a hint for compilers to inline the definition, but no compilers actually take that into account any more.

You shouldn't believe everything you see on the internet.

Of course, `inline` has mandatory effects on linkage and whatnot, but this post is only interested in whether or not compilers might change the decision to inline a function or not based on whether you write `inline` in the declaration.

However, the point of this article isn't to give you good rules for when to use `inline`, because as much as I like to debate technical minutiae, your compiler will likely be a better judge than you anyway. Instead I want to show that if you want to know how compilers or standard libraries implement things, you can just go look! It might be scary the first time, but getting a knack for finding things in large code bases and understanding your tools can pay off. I'll be diving into the codebases for Clang and GCC to see how they handle inlining hints and hopefully convince you that you can do the same for questions which you have about your tools.

--------

### Clang

Let's do this bottom-up. Clang is a compiler frontend for LLVM, which means that it takes C-family languages, translates them to LLVM Intermediate Representation, and LLVM handles generating assembly/binaries from that. So we can dig around in LLVM to see if we can find code which deals with inlining. I found the following code in `llvm/lib/Analysis/InlineCost.cpp`:

{% highlight cpp %}
  // Adjust the threshold based on inlinehint attribute and profile based
  // hotness information if the caller does not have MinSize attribute.
  if (!Caller->optForMinSize()) {
    if (Callee.hasFnAttribute(Attribute::InlineHint))
      Threshold = MaxIfValid(Threshold, Params.HintThreshold);
    if (PSI) {
      uint64_t TotalWeight;
      if (CS.getInstruction()->extractProfTotalWeight(TotalWeight) &&
          PSI->isHotCount(TotalWeight)) {
        Threshold = MaxIfValid(Threshold, Params.HotCallSiteThreshold);
      } else if (PSI->isFunctionEntryHot(&Callee)) {
        // If callsite hotness can not be determined, we may still know
        // that the callee is hot and treat it as a weaker hint for threshold
        // increase.
        Threshold = MaxIfValid(Threshold, Params.HintThreshold);
      } else if (PSI->isFunctionEntryCold(&Callee)) {
        Threshold = MinIfValid(Threshold, Params.ColdThreshold);
      }
    }
  }
{% endhighlight %}

By just looking at this code without knowledge of all the other functions, we won't be able to totally understand what it's doing. But there's certainly some information we can gleam here:

{% highlight cpp %}
    if (Callee.hasFnAttribute(Attribute::InlineHint))
      Threshold = MaxIfValid(Threshold, Params.HintThreshold);
{% endhighlight %}      

So now we know that LLVM takes the presence of an `inlinehint` attribute into account in its inlining cost model. But does Clang produce that attribute? Let's look for that attribute in the Clang sources:

{% highlight cpp %}
    // Otherwise, propagate the inline hint attribute and potentially use its
    // absence to mark things as noinline.
    if (auto *FD = dyn_cast<FunctionDecl>(D)) {
      if (any_of(FD->redecls(), [&](const FunctionDecl *Redecl) {
            return Redecl->isInlineSpecified();
          })) {
        B.addAttribute(llvm::Attribute::InlineHint);
      } else if (CodeGenOpts.getInlining() ==
                     CodeGenOptions::OnlyHintInlining &&
                 !FD->isInlined() &&
                 !F->hasFnAttribute(llvm::Attribute::AlwaysInline)) {
        B.addAttribute(llvm::Attribute::NoInline);
      }
    }
{% endhighlight %}

The above code from `clang/lib/CodeGen/CodeGenModule.cpp` shows Clang setting the `inlinehint` attribute. It will also possibly mark declarations as `noinline` if `inline` was not supplied (depending on compiler flags). Now we can look for code which affects `isInlineSpecified`:


{% highlight cpp %}
// clang/include/clang/Sema/DeclSpec.h
bool isInlineSpecified() const {
  return FS_inline_specified | FS_forceinline_specified;
}

// clang/lib/Sema/DeclSpec.cpp
bool DeclSpec::setFunctionSpecInline(SourceLocation Loc, const char *&PrevSpec,
                                     unsigned &DiagID) {
  // 'inline inline' is ok.  However, since this is likely not what the user
  // intended, we will always warn, similar to duplicates of type qualifiers.
  if (FS_inline_specified) {
    DiagID = diag::warn_duplicate_declspec;
    PrevSpec = "inline";
    return true;
  }
  FS_inline_specified = true;
  FS_inlineLoc = Loc;
  return false;
}

// Parse/ParseDecl.cpp:ParseDeclarationSpecifiers
  case tok::kw_inline:
    isInvalid = DS.setFunctionSpecInline(Loc, PrevSpec, DiagID);
    break;
{% endhighlight %}

The above snippets show the functions which set and retrieve whether something was specified as inline, and the code in the parser which calls the setter.

So now we know that Clang propagates the presence of the `inline` keyword through to LLVM using the `inlinehint` attribute, and that LLVM takes this into account in its cost model for inlining. Our detective work has been successful!

---------------------

## GCC

How about GCC? The source for GCC is a fair bit less accessible than that of LLVM, but we can still make an attempt. After a bit of searching, I found that the `DECL_DECLARED_INLINE_P` macro seemed to be used lots of places which were relevant. So we can look for where that's set: 

{% highlight cpp %}
        // c/c-decl.c:grokdeclarator

	/* Record presence of `inline' and `_Noreturn', if it is
	   reasonable.  */
	if (flag_hosted && MAIN_NAME_P (declarator->u.id))
	  {
	    if (declspecs->inline_p)
	      pedwarn (loc, 0, "cannot inline function %<main%>");
	    if (declspecs->noreturn_p)
	      pedwarn (loc, 0, "%<main%> declared %<_Noreturn%>");
	  }
	else
	  {
	    if (declspecs->inline_p)
	      /* Record that the function is declared `inline'.  */
	      DECL_DECLARED_INLINE_P (decl) = 1;
	    if (declspecs->noreturn_p)
	      {
		if (flag_isoc99)
		  pedwarn_c99 (loc, OPT_Wpedantic,
			       "ISO C99 does not support %<_Noreturn%>");
		else
		  pedwarn_c99 (loc, OPT_Wpedantic,
			       "ISO C90 does not support %<_Noreturn%>");
		TREE_THIS_VOLATILE (decl) = 1;
	      }
	  }
{% endhighlight %}

We can then look for uses of this macro which seem to affect the behaviour of the inliner. Here are a few:

{% highlight cpp %}
  //ipa-inline.c:want_inline_small_function_p    

  /* Do fast and conservative check if the function can be good
     inline candidate.  At the moment we allow inline hints to
     promote non-inline functions to inline and we increase
     MAX_INLINE_INSNS_SINGLE 16-fold for inline functions.  */
  else if ((!DECL_DECLARED_INLINE_P (callee->decl)
	   && (!e->count.ipa ().initialized_p () || !e->maybe_hot_p ()))
	   && ipa_fn_summaries->get (callee)->min_size
		- ipa_call_summaries->get (e)->call_stmt_size
	      > MAX (MAX_INLINE_INSNS_SINGLE, MAX_INLINE_INSNS_AUTO))
    {
      e->inline_failed = CIF_MAX_INLINE_INSNS_AUTO_LIMIT;
      want_inline = false;
    }


  //ipa-inline.c:edge_badness
  
  /* ... and do not overwrite user specified hints.   */
  && (!DECL_DECLARED_INLINE_P (edge->callee->decl)
      || DECL_DECLARED_INLINE_P (caller->decl)))))


  //ipa-inline.c:early_inline_small_functions

  /* Do not consider functions not declared inline.  */
  if (!DECL_DECLARED_INLINE_P (callee->decl)
	  && !opt_for_fn (node->decl, flag_inline_small_functions)
	  && !opt_for_fn (node->decl, flag_inline_functions))
	continue;
{% endhighlight %}

That's some evidence that the keyword is being taken into account. If we want to get a better idea of all of the effects, then we now have a starting point from which to conduct our expectations.

----------

## Conclusion

I hope I've managed to convince you of two things:
{:.listhead}

1. Some modern compilers still take inline hints into account.
2. If you want to understand how your compiler works and it's open source, you can just go and look.

If you're actually going to try and optimize your code using `inline` then Do The Right Thing And Measure It[^1]. See what your compiler actually generates. Profile your code to make sure you're opmitizing something that needs optimizing. Don't guess.

-------------

[^1]: DTRTAMI (dee-tee-arr-tamee) kinda has a ring to it.


