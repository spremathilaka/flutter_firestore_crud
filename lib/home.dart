import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  @override
  _Home createState() => _Home();
}

class _Home extends State<StatefulWidget> {
  var _totalDocs = 0;
  var _queriedDocs = 0;
  var _interactionCount = 0;

  final _myContr = TextEditingController();
  final _getContr = TextEditingController();
  final _myUpdateContr = TextEditingController();

  bool _switchOnOff = false;
  var _listener;
  var _transactionListener;

  @override
  void initState() {
    super.initState();
    _transactionListener = Firestore.instance
        .collection('stats')
        .document('interactions')
        .snapshots()
        .listen((data) => transactionListenerUpdate(data));
  }

  void transactionListenerUpdate(data) {
    var number = data['count'];
    setState(() {
      _interactionCount = number;
    });
  }

/*  To write to Firestore, add the following clickWrite() method. Also, note, that the interact()
  method will make a transaction to the Cloud Firestore database, every time we interact
  with the app (for example write something, delete something or update something, etc.).*/
  void clickWrite() async {
    if (_myContr.text.isNotEmpty) {
      await Firestore.instance
          .collection('docs')
          .document()
          .setData({'text': _myContr.text});
      _myContr.text = '';
      interact();
    }
  }

/*  For updating an entry, we first create a small dialogue box, that opens when we click
  on ‘Edit’. Then, the dialogue box shows a TextField with the entry and a RaisedButton
  to execute the update.
  So with that functionality, we can change an entry.*/

  void clickEdit(item) {
    _myUpdateContr.text = item['text'];

    showDialog(
        context: context,
        builder: (_) => SimpleDialog(
              title: Text('Edit text'),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _myUpdateContr,
                          decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter new Text!'),
                        ),
                      ),
                      RaisedButton(
                        color: Colors.orange,
                        textColor: Colors.white,
                        splashColor: Colors.orangeAccent,
                        child: const Text('Update'),
                        onPressed: () {
                          clickUpdate(item);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ));
  }

/*  When we click on ‘Update’, we call clickUpdate(), and we update the Firestore database.
  In addition, we count this as an interaction and at the end we pop() our dialogue
  box so that we navigate back to our main screen.*/

  void clickUpdate(item) async {
    await Firestore.instance
        .collection('docs')
        .document(item.documentID)
        .updateData({'text': _myUpdateContr.text});
    interact();
    Navigator.pop(context);
  }

/*    With a click on our ‘Get’ button, we count all entries in our current database,
    that have a specific text (the text we wrote into the TextField).
    And the Text above the button will display how many entries with that text were found.
    Also, this too counts as an interaction.*/

  void clickGet() async {
    if (_getContr.text.isNotEmpty) {
      var query = await Firestore.instance
          .collection('docs')
          .where('text', isEqualTo: _getContr.text)
          .getDocuments();
      setState(() {
        _queriedDocs = query.documents.length;
      });
      interact();
    }
  }

  void removeFromDb(itemID) {}

/*  Whenever we turn on our switch, we start listening and show, how many entries
  there currently are in our database. And if we turn off the switch,
  we cancel() the subscription and stop listening for changes.
  Turning the Listener on/off does not count as an interaction here.
  But you could easily change that if you think it should count as an interaction too.*/

  void switchListener(isOn) async {
    bool switcher;
    switch (isOn) {
      case true:
        switcher = true;
        _listener = Firestore.instance
            .collection('docs')
            .snapshots()
            .listen((data) => listenerUpdate(data));
        break;
      case false:
        switcher = false;
        await _listener.cancel();
        break;
    }
    setState(() {
      _switchOnOff = switcher;
    });
  }

  void listenerUpdate(data) {
    var number = data.documents.length;
    setState(() {
      _totalDocs = number;
    });
  }

  void interact() async {
    final DocumentReference postRef =
        Firestore.instance.collection('stats').document('interactions');
    await Firestore.instance.runTransaction((Transaction tx) async {
      DocumentSnapshot postSnapshot = await tx.get(postRef);
      if (postSnapshot.exists) {
        await tx.update(postRef,
            <String, dynamic>{'count': postSnapshot.data['count'] + 1});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Firestore Tutorial'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(child: Text('Total Interactions: $_interactionCount')),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _myContr,
                    decoration: InputDecoration(
                        border: InputBorder.none, hintText: 'Enter Text'),
                  ),
                ),
                RaisedButton(
                  color: Colors.cyan,
                  textColor: Colors.white,
                  splashColor: Colors.cyanAccent,
                  child: const Text('Write to Firestore'),
                  onPressed: clickWrite,
                ),
              ],
            ),
            Divider(),
            Center(
              child:
                  Text('Get Number of Docs with specific Text: $_queriedDocs'),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _getContr,
                    decoration: InputDecoration(
                        border: InputBorder.none, hintText: 'Enter Text'),
                  ),
                ),
                RaisedButton(
                  color: Colors.amber,
                  textColor: Colors.white,
                  splashColor: Colors.amberAccent,
                  child: const Text('Get'),
                  onPressed: clickGet,
                ),
              ],
            ),
            Divider(),
            Center(child: Text('Documents in Store: $_totalDocs')),
            Row(
              children: <Widget>[
                Expanded(child: Text('Turn on Listener')),
                Switch(
                    value: _switchOnOff,
                    onChanged: (val) {
                      switchListener(val);
                    }),
              ],
            ),
            Divider(),

            Expanded(
                child: StreamBuilder<QuerySnapshot>(
              stream: Firestore.instance.collection('docs').snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');

                switch (snapshot.data) {
                  case null:
                    return Container();
                  default:
                    return ListView.builder(
                      itemCount: snapshot.data.documents.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data.documents[index];
                        final itemID =
                            snapshot.data.documents[index].documentID;
                        final list = snapshot.data.documents;

                        return Dismissible(
                          key: Key(itemID),
                          onDismissed: (direction) {
                            removeFromDb(itemID);
                            setState(() {
                              list.removeAt(index);
                            });
                          },
                          // Show a red background as the item is swiped away
                          background: Container(color: Colors.red),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: ListTile(
                                  title: Text(item['text']),
                                ),
                              ),
                              RaisedButton(
                                color: Colors.blue,
                                textColor: Colors.white,
                                splashColor: Colors.blueAccent,
                                child: const Text('Edit'),
                                onPressed: () {
                                  clickEdit(item);
                                },
                              ),
                            ],
                          ),
                        );
                        //...

                        //...
                      },
                    );
                }
              },
            ))

            //...
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up controllers when disposed
    _myContr.dispose();
    _getContr.dispose();
    _myUpdateContr.dispose();

    // Cancel transaction listener subscription
    _transactionListener.cancel();

    super.dispose();
  }
}
