# VLCSyphon

This repository is a remote of the vlc Git that you can find here:
<https://wiki.videolan.org/Git>

Why not fork the original? Their environment is not as friendly as GitHub, and have no intention to push this to VLC master branch, so I think it's easier for everybody to get this here.

Initially cloned from:

<pre>
commit f2de0fc0fa07d2a8f3ce80d2a892f1326653632c
Date:   Wed Jul 13 22:02:46 2016 +0200
</pre>

I'll try to merge and udate this remote often.


# Building

XCode Project is at `extras/package/macosx/vlc.xcodeproj`, but not buildable.

To build VLCSyphon use the *Syphon* branch:

<pre>
cd VLCSyphon
git checkout Syphon
cd build
./make_syphon
</pre>

The app will be at `build/VLCSyphon.app`.



