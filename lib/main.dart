import 'dart:io';

import 'package:data_usage/data_usage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:location/location.dart' ;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

void main() {
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
  List<List<dynamic>>? rowsAsListOfValues=[];
  List result = [];
  static const platform = const MethodChannel('com.cashful.deviceinformation/userdata');
  Location location = new Location();

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
    print(_locationData.latitude);
    setState(() {
      result = [
        {
          'lat': _locationData.latitude,
          'long': _locationData.longitude,
        }
      ];
    });
  }

  Future<void> getContacts() async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
      result = [];
      contacts.forEach((element) {
        Map oneC = element.toJson();
        setState(() {
          result.add(oneC);
        });
      });

    }

  }
  Widget buttons (callName){
    return  Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
            width: MediaQuery.of(context).size.width*0.25,
            child: Text(callName)),
        ElevatedButton(
            onPressed: () async {
              try {
                await  platform.invokeMethod(callName).then((value) async {
                  setState(() {
                    result = value;
                  });
                  print(result);
                });

              } on PlatformException catch (e) {
                print(e.toString());
              }
            },
            child: Text('Fetch & Show')
        ),
        ElevatedButton(
            onPressed: () async {
              if (await permission.Permission.storage.request().isGranted) {
                final String directory = (await getExternalStorageDirectory())!
                    .path;
                final path = "$directory/csv-$callName${DateTime.now()}.csv";
                rowsAsListOfValues = [];
                if(result.isNotEmpty) {
                  rowsAsListOfValues?.add(result[0].keys.toList());
                }
                for (Map element in result) {
                  setState(() {
                    rowsAsListOfValues!.add(element.values.toList());
                  });
                }
                String csvData = ListToCsvConverter().convert(
                    rowsAsListOfValues);
                print(csvData);
                final File file = File(path);
                await file.writeAsString(csvData).then((value) async {
                  print(await value.exists());
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully exported csv to local files'),));
                });
              }
              else{

                Map<permission.Permission, permission.PermissionStatus> statuses = await [
                  permission.Permission.storage,
                ].request();
              }
            },
            child: Text('Export')
        ),
      ],
    );
  }

  @override
  void initState() {
    DataUsage.init();
    super.initState();
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
            buttons('getCallLog'),
            buttons('appInstall'),
            buttons('dataUsage'),
            buttons('device'),
            buttons('sms'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                    width: MediaQuery.of(context).size.width*0.25,
                    child: Text('Location')),
                ElevatedButton(
                    onPressed: () async {
                     getLocation();
                    },
                    child: Text('Fetch & Show')
                ),
                ElevatedButton(
                    onPressed: () async {
                      if (await permission.Permission.storage.request().isGranted) {
                        final String directory = (await getExternalStorageDirectory())!
                            .path;
                        final path = "$directory/csv-location${DateTime.now()}.csv";
                        rowsAsListOfValues = [];
                        if(result.isNotEmpty) {
                          rowsAsListOfValues?.add(result[0].keys.toList());
                        }
                        for (Map element in result) {
                          setState(() {
                            rowsAsListOfValues!.add(element.values.toList());
                          });
                        }
                        String csvData = ListToCsvConverter().convert(
                            rowsAsListOfValues);
                        print(csvData);
                        final File file = File(path);
                        await file.writeAsString(csvData).then((value) async {
                          print(await value.exists());
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully exported csv to local files'),));
                        });
                      } else{

                        Map<permission.Permission, permission.PermissionStatus> statuses = await [
                          permission.Permission.storage,
                        ].request();
                      }
                    },
                    child: Text('Export')
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                    width: MediaQuery.of(context).size.width*0.25,
                    child: Text('Contacts')),
                ElevatedButton(
                    onPressed: () async {
                      getContacts();
                    },
                    child: Text('Fetch & Show')
                ),
                ElevatedButton(
                    onPressed: () async {
                      if (await permission.Permission.storage.request().isGranted) {
                        final String directory = (await getExternalStorageDirectory())!
                            .path;
                        final path = "$directory/csv-location${DateTime.now()}.csv";
                        rowsAsListOfValues = [];
                        if(result.isNotEmpty) {
                          rowsAsListOfValues?.add(result[0].keys.toList());
                        }
                        for (Map element in result) {
                          setState(() {
                            rowsAsListOfValues!.add(element.values.toList());
                          });
                        }
                        String csvData = ListToCsvConverter().convert(
                            rowsAsListOfValues);
                        print(csvData);
                        final File file = File(path);
                        await file.writeAsString(csvData).then((value) async {
                          print(await value.exists());
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully exported csv to local files'),));
                        });
                      } else{

                        Map<permission.Permission, permission.PermissionStatus> statuses = await [
                          permission.Permission.storage,
                        ].request();
                      }
                    },
                    child: Text('Export')
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: result.length,
                itemBuilder: (context,index) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('${result[index]}'),
              );
            }),
          ],
        ),
      ),
    );
  }
}
