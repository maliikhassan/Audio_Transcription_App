import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:untitled1/screens/HomeScreen.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  File? filePath;

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    File imageMap = File(image.path);
    setState(() {
      filePath = imageMap;
    });

    //await Get.to(()=> HomeScreen(imageMap: imageMap));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cotton Seeds classifier"),
        actions: [
          IconButton(onPressed: (){}, icon: Icon(Icons.dark_mode))
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(vertical: 12,horizontal: 30),
        child: Column(
          spacing: 20,
          children: [
            Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2), // Shadow color
                    spreadRadius: 2, // How much the shadow spreads
                    blurRadius: 5, // How blurry the shadow is
                    offset: Offset(2, 5), // X and Y offset of the shadow
                  ),
                ],
              ),
              child: Image.asset("assets/cotton.png"
                ,
              ),
            ),
            Text("Pick From Gallery or Capture Image for Seed Classificatio"),
            Expanded(
              child: InkWell(
                onTap: (){
                  _pickImage(ImageSource.camera);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.lightGreen,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 15,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedCamera02, color: Colors.white),
                      Text("Capture Image",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 20),)
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: (){
                  _pickImage(ImageSource.gallery);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.lightGreen,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 15,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: Colors.white),
                      Text("From Gallery",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 20),)
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: (){},
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.lightGreen,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 15,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedWorkHistory, color: Colors.white),
                      Text("Show History",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 20),)
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 10,)
          ],
        ),
      ),
    );
  }
}
