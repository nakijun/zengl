# move binary into bundle
mv -f ../../../bin/demo01 ../../../bin/demo01.app/Contents/MacOS/demo01
ln -s ../../../bin/demo01.app/Contents/MacOS/demo01 ../../../bin/demo01
# make Info.plist and copy icon
cp -f demo01_macosx.plist ../../../bin/demo01.app/Contents/Info.plist
cp ../../../bin/data/zengl.icns ../../../bin/demo01.app/Contents/Resources/demo01.icns