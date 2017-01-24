---
layout:     post
title:      "Toxicity in tech -- my personal journey"
category:   social-tech
tags:
 - social-tech
---

The easiest thing would have been for me to go and take some of the myriad sarcastic comments from a beginner-level Stack Overflow question, but I've chosen the hard path: I went through some of my old Stack Overflow, Reddit and Hipchat comments and picked out real-life examples of times in the past when I've been a dick on the internet. 

> *Beginner posts basic Stack Overflow question*
>
> Me: At least make an attempt at this before posting for help.

> Beginner: Maybe this sounds like a stupid idea, but...
>
> Me: Yes, that does sound like a stupid idea.

> Colleague: TIL about Fluxx. It's cool that I can have a card game like this to play with my non-gamer friends.
>
> Me: Fluxx is everything wrong with board/card games.

> Beginner: I'm having some problems with this OpenGL program.
>
> Me: So you *want* to draw a shader when it has failed to load!? You need to think through the logic of your program. The if-statement in your question is triggered when the file can't be found, thus making the shader in a useless state. You then attempt to use this useless shader.

> Beginner: Why doesn't this code work?
>
> Me: Don't return a reference to a local temporary object.

> Beginner: Why is this a garbage value?
>
> Me: It's a garbage value because it doesn't mean anything in context.

Maybe you're reading those and thinking that they aren't all that bad. Maybe that would be the case in some contexts, but I know for a fact that some of these comments hurt people or turned people away from the community. That first one? The poster of the question never posted on SO again. The Fluxx one? He certainly never spoke to me about card games after that, even though I know for a fact that he was passionate about Magic.

I don't make any excuses for these contributions, or worse ones which have been lost down the back of the Internet sofa. But I *do* try and learn from them.

However, while I wish that we didn't have to deal with ad-homenim attacks, unconstructive criticism, and the like, I do really appreciate direct feedback. Here's a comment from Reddit on one of my recent blog posts.

> `T{}` may be either value-initialization or aggregate initialization or "plain" initialization calling an initializer-list constructor, depending on `T`.
>
> "you can’t default-initialize a const-qualified object if it lacks a user-provided constructor,"
>
>That's not the rule anymore, thankfully. See Core DR 253, resolved by P0490R0 (scroll to the bottom).
>
> "The language mandates that the type without the user-provided constructor is value-initialized and the type with is default-initialized."
>
>That's not quite how it works. In your initial example, `a` is aggregate-initialized; `b` is value-initialized but its value-initialization doesn't do zero-initialization.
>
>"ordered"'s description is incorrect. That category also include all "plain" non-local static/thread-local variables. If "non-trivial" is referring to [basic.life], it's now called "non-vacuous" and covers all initialization except by a trivial default constructor.

I would say that this is excellent feedback. It explicitly addresses inaccuracies in the post and provides corrections for each point in turn, all without a sense of condescension or malice. Maybe you wouldn't call it "polite", but if you want to correct someone's post, this is a good way to do it.
