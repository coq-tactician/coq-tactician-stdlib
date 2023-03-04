# Compile the Coq standard library with Tactician support

For the main Tactician repository, see [coq-tactician](https://github.com/coq-tactician/coq-tactician)

**Note:** As of Coq 8.17, this package is no longer needed because Coq's standard
library has been split off from Coq's core (there are now Opam packages `coq-core`
and `coq-stdlib`). In order to compile `coq-stdlib` with support for Tactician,
follow the [package instumentation instructions](https://coq-tactician.github.io/manual/coq-packages/)
in the manual.

This package recompiles Coq's standard library with Tactician's (`coq-tactician`)
instrumentation loaded such that Tactician can learn from the library. When you
install this package, the current `.vo` files of the standard library are backed
in the folder `user-contrib/Tactician/stdlib-backup`. The new `.vo` files are
equivalent to the originals, except that they also contain Tactician's tactic
databases. After installation of this package, all other Coq developments that
are installed will also need to be recompiled. The 'tactician recompile' command
line utility can help with this.
Upon removal of this package, the original files will be placed back.
