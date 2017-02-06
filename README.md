#OSVR-Cardboard-iOS [![Donate](https://nourish.je/assets/images/donate.svg)](http://ko-fi.com/A250KJT)

An iOS app for playing OSVR-compatible PC games using a Google Cardboard viewer. Forked from [Moonlight](https://github.com/moonlight-stream/moonlight-ios).

##Usage

Set up NVidia SHIELD Remote Desktop according to [the instructions from NVidia](http://nvidia.custhelp.com/app/answers/detail/a_id/3489/~/shield-remote-desktop). Install and configure the [OSVR-Cardboard plugin](https://github.com/simlrh/OSVR-Cardboard).

Run the app and swipe right to get to the settings page. Tap "Scan QR Code" and scan the code on your Cardboard viewer. Then tap Add Host to pair with your PC. Tap the host to connect and place your phone in the viewer. You can swipe right to disconnect.

The connection may drop when you switch away from a fullscreen game on your PC - this seems to be the way NVidia GameStream works. Just tap the host again to reconnect.
