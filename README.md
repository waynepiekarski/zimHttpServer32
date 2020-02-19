
This repo is DEPRECATED and here for reference purpose only, it may be deleted from github at any time in the future.

The clone was originally done with the intention
of integration into freetz, thus the content of
the few commits in this repo has basically moved
to
https://github.com/cm8/freetz/commits/make/zimhttpserver

Due to the way freetz packages work, there is not
a full clone - make/zimhttpserver/zimhttpserver.mk
rather refers to the original upstream repo,
instead of cloning it fully into freetz. The
reason for freetz to do it this way is, that
it is unclear if a clone is needed until the
user has configured freetz build system.

After some grace period, /this/ fork will probably
be deleted, because the original intention of
integration into freetz is now finished. If you
have bookmarked it for some reason, take a look
at
https://github.com/cm8/freetz/commit/a89bb115d2d9ec47f7ad85dc3ec24a286b6b1a64

This commit basically squashes the changes done
to this repo since fork time.
