> [!IMPORTANT]
> **This project is discontinued. Use [vlc-syphon-ndi](https://github.com/rsodre/vlc-syphon-ndi) instead.**
>
> vlc-syphon-ndi brings **VLCSyphon.app** and **VLCNDI.app**, based on the current official VLC
> (3.0.24), for macOS 11+ on Apple Silicon and Intel. They're signed and notarized, and Syphon
> also works with hardware-decoded video. NDI® output with sound comes too, and the plugins can
> also be added to the official VLC.
> [Download the latest release](https://github.com/rsodre/vlc-syphon-ndi/releases/latest).
>
> This repository is a 2016 fork of VLC 3.0.0-git. It's kept for reference only and is no longer
> maintained.

![VLCSyphon](https://raw.githubusercontent.com/rsodre/VLCSyphon/Syphon/VLCSyphon.png)

# VLCSyphon

**VLCSyphon** is a build of the [VLC Media Player](http://www.videolan.org/vlc/index.html) with a [Syphon](http://syphon.v002.info/) server inside. It allows us to play movies and use it as a teture on any Syphon-enabled application.

# Usage

If you just want to play files, [download the latest release](https://github.com/rsodre/VLCSyphon/releases).

It will publish the video frames at the full encoded resolution, it is NOT limited to the player window.

# Building

This repository is a remote of the vlc Git that you can find here:
<https://wiki.videolan.org/Git>

Why not fork the original? Their environment is not as friendly as GitHub, and have no intention to push this to VLC master branch, so I think it's easier for everybody to get this here. I'll try to merge and update this remote often.

The XCode Project is at `extras/package/macosx/vlc.xcodeproj`, but not buildable.

To build VLCSyphon use the **Syphon** branch:

<pre>
cd VLCSyphon
git checkout Syphon
cd build
./make_syphon
</pre>

The app will be at `build/VLCSyphon.app`.



