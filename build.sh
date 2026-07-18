#!/bin/bash

# 1. Clone the Flutter SDK (stable channel)
echo "Cloning Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# 2. Add Flutter to the path
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Verify flutter installation
flutter --version

# 4. Navigate to the mobile folder and compile the web app
echo "Building Flutter Web application..."
cd mobile
flutter build web --release

# 5. Navigate back and copy output to public directory for Vercel
cd ..
mkdir -p public
cp -r mobile/build/web/* public/

echo "Flutter Web deployment build succeeded!"
