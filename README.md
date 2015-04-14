**Original Author**: Fredrik Hubinette

Auto-recompile is a small emacs add-on which allows you to fix compilation errors faster by automatically runs compile command on save.

# Usage:
  M-x auto-recompile will toggle auto-recompile on and off.

When auto-recompile is active, your emacs will do some extra things:

When you save a file, emacs will start a new compilation with the same
parameters as the last call to M-x compile. Any active previous compilation
will be killed, but it's buffer will remain so that you can still work
on any compilation errors in that buffer. Each new compilation will live
in it's own buffer.

When you hit C-x ` to go to the next error, emacs will search all compilation
buffers, starting with the newest one until it finds one that has an error.
When it finds a buffer with an error, older compilation buffers will be
killed automatically as any error in those buffers aren't interesting anymore.

If no error is found, emacs will show you the end of thelast compilation buffer.
This will tell you if the current compilation is still active, or if it
completed successfully.

When using C-`, emacs will automatically save ALL buffers if the next error
is in a different buffer than the last one. This will automatically start a
new compilation.

So, what does all this mean?
It means that after starting a compile with M-x compile, all you need to do
is to use C-x ` to go from error to error and fix them. Emacs will automatically
save and recompile as you work your way through the files. Occationally you may
want to save file explicitly, but it should not be needed.

# WARNING
auto-recompile mode can be dangerous. It will kill compilations without warning,
and it will save ALL buffers in your emacs without asking. To turn off the 
automatic saving of buffers, set auto-recompile-save to nil.
