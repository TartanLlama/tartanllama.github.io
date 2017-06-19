==================================== ERRORS ====================================

-- TYPE MISMATCH --------------------------------------------- repl-temp-000.elm

The argument to function `get` is causing a mismatch.

5|            Machine.get (Elmscrew.Machine.initialize 10)
                                    ^^^^^^^^^^^^^^^^^^^^^
Function `get` is expecting the argument to be:

    { a | postion : Int, tape : Array.Array number }

But it is:

    Elmscrew.Machine.Machine

Hint: The record fields do not match up. Maybe you made one of these typos?

    postion <-> position


-- TYPE MISMATCH -------------------------------------- ././Elmscrew/Machine.elm

`machine` does not have a field named `postion`.

13| set machine i = Array.set machine.postion i machine.tape
                              ^^^^^^^^^^^^^^^
The type of `machine` is:

    Machine

Which does not contain a field named `postion`.

Hint: The record fields do not match up. Maybe you made one of these typos?

    position <-> postion
