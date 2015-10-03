NSLua
=====

NSLua is an easy to integrate and easy to use library for bridging Obj-C and Lua.
It was derived from EasyLua, by David Holtkamp at Crimson Moon Entertainment, which in turn was derived from Lua-Objective-C Bridge by Toru Hisai.

How to use
==========

To use NSLua in your iOS or OS X application, you should drop the .h, .m and .lua files into your XCode project. You should also add a Lua source distribution as a directory into your Xcode project. (Xcode will build Lua by calling `make` on this directory. It just works.)

Now to run a piece of Lua code:

    [[NSLua sharedNSLua] runLuaString:@"print(\"Hello World\")"];
    [[NSLua sharedNSLua] runLuaBundleFile:@"MyCode.lua"]

All Objective C classes in the binary are available for use in Lua. Properties are available as properties, and methods are available as methods. Objective C methods which take multiple arguments should have their colons replaced with underscores. For example:

    fileurl = NSURL:fileURLWithPath_(path)
    print(fileurl) # "<NSUrl>"
    print(fileurl.absoluteString) # "file:///..."

    NSDocumentController.sharedDocumentController:openDocumentWithContentsOfURL_display_error_(fileurl, true, nil)

Properties can be set in the usual way:

    lastPoint.x = 10

Data will be marshalled between Lua data types and their Objective C equivalents; arrays and dictionaries will be converted to tables and back again.

License
=======
Portions copyrighted by Toru Hisai, 2015 and Crimson Moon Entertainment LLC, 2015.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Author
======

NSLua: Simon Cozens simon@simon-cozens.org

EasyLua: David Holtkamp david@crimson-moon.com

Lua-Objective-C Bridge Author: Toru Hisai toru@torus.jp @torus 
