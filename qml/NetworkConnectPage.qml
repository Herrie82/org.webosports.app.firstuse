/*
 * Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.0
import QtQuick.Controls 1.0
import LunaNext.Common 0.1
import firstuse 1.0

BasePage {
    id: page

    property string ssid: ""
    property var securityTypes: []

    title: "Connect to " + ssid
    customBack: true
    forwardButtonSourceComponent: forwardButton

    LunaService {
        id: connectNetwork
        name: "org.webosports.app.firstuse"
        usePrivateBus: true
        service: "luna://com.palm.wifi"
        method: "connect"

        onResponse: function (message) {
            console.log("response: " + message.payload);
        }
    }

    Item {
        anchors.fill: content

        MouseArea {
            anchors.fill: parent
            onPressed: {
                mouse.accepted = false;
                var selectedItem = root.childAt(mouse.x, mouse.y);
                if (!selectedItem)
                    selectedItem = root;
                selectedItem.focus = true;
            }
        }

        Column {
            id: column
            anchors.fill: parent
            spacing: Units.gu(1)

            Label {
                text: "Enter passphrase"
                color: "white"
                font.pixelSize: FontUtils.sizeToPixels("medium")
            }

            TextInput {
                id: passphrase

                height: Units.gu(4)

                anchors.left: parent.left
                anchors.right: parent.right

                font.pixelSize: FontUtils.sizeToPixels("medium")
                echoMode: TextInput.Password
                passwordCharacter: "•"

                onActiveFocusChanged: {
                    if (passphrase.focus)
                        Qt.inputMethod.show();
                    else
                        Qt.inputMethod.hide();
                }
            }

            Label {
                id: passphraseHint
                visible: false
                color: "red"
                text: "Please enter a passphrase!"
                font.pixelSize: FontUtils.sizeToPixels("medium")
            }
        }
    }

    function connectNetwork() {
        if (passphrase.length === 0) {
            passphraseHint.visible = true;
            return;
        }

        passphraseHint.visible = false;

        connectNetwork.call(JSON.stringify({
            ssid: page.ssid,
            security: {
                simpleSecurity: {
                    passKey: passphrase.text
               }
            }
        }));

        pageStack.pop();
    }

    Component {
        id: forwardButton
        StackButton {
            text: "Connect"
            onClicked: page.connectNetwork()
        }
    }

    onBackClicked: {
        // go back to page which push us to the stack
        pageStack.pop()
    }
}
