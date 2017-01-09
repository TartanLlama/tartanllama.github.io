---
layout:     post
title:      "C++17 attributes - maybe_unused, fallthrough and nodiscard"
category:   c++
tags:
 - c++ 
 - c++17
---

C++17 adds three new attributes for programmers to better express their intent to the compiler and readers of the code. This is a quick post to outline what they do and why they are useful.

-------------------

### `maybe_unused`

`[[maybe_unused]]` suppresses compiler warnings about unused entities. Usually unused functions or variables indicates a programmer error -- if you never use it, why is it there? -- but sometimes they can be intentional, such as variables which are only used in release mode, or functions only called when logging is enabled.

#### Variables
{% highlight cpp %}
void emits_warning(bool b) {
     bool result = get_result();
     // Warning emitted in release mode
     assert (b == result);
     //...
}

void warning_suppressed(bool b [[maybe_unused]]) {
     [[maybe_unused]] bool result = get_result();
     // Warning suppressed by [[maybe_unused]]
     assert (b == result);
     //...
}
{% endhighlight %}

#### Functions

{% highlight cpp %}
static void log_with_warning(){}
[[maybe_unused]] static void log_without_warning() {}

#ifdef LOGGING_ENABLED
log_with_warning();    // Warning emitted if LOGGING_ENABLED is not defined
log_without_warning(); // Warning suppressed by [[maybe_unused]]
#endif
{% endhighlight %}

-------------------

### `fallthrough`

`[[fallthrough]]` indicates that a fallthrough in a switch statement is intentional. Missing a `break` or `return` in a switch case is a very common programmer error, so compilers usually warn about it, but sometimes a fallthrough can result in some very terse code.

Say we want to process an alert message. If it's green, we do nothing; if it's yellow, we record the alert; if it's orange we record *and* trigger the alarm; if it's red, we record, trigger the alarm and evacuate.

{% highlight cpp %}
void process_alert (Alert alert) {
     switch (alert) {
     case Alert::Red:
         evacuate();
         // Warning: this statement may fall through

     case Alert::Orange:
         trigger_alarm();
         [[fallthrough]]; //yes, you do need the semicolon
         // Warning suppressed by [[fallthrough]]

     case Alert::Yellow:
         record_alert();
         return;
         
     case Alert::Green:
         return;
     }
}
{% endhighlight %}

-------------------

### `nodiscard`

