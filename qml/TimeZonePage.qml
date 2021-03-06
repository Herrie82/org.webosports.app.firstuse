/*
* Copyright (C) 2014 Simon Busch <morphis@gravedo.de>
* Copyright (C) 2015 Herman van Hazendonk <github.com@herrie.org>
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
*You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

import QtQuick 2.3
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.0
import LunaNext.Common 0.1
import LuneOS.Service 1.0
import firstuse 1.0
import "js/GlobalState.js" as GlobalState


BasePage {
    title: "Select your Timezone"
    forwardButtonSourceComponent: forwardButton

    property variant currentTimezone: null
    property string currentRegion: ""
    property int currentTimezoneIndex: -1
    property int currentDifference: -1
    property int currentTimezoneIndexPreferredTemp: -1
    property int currentTimezoneIndexPreferred: -1
    property int currentTimezoneIndexPreferredOffset: -1
    property int finalIndex: -1

    LunaService {
        id: service
        name: "org.webosports.app.firstuse"
        usePrivateBus: true
    }


    Component.onCompleted: {
        service.call("luna://com.palm.systemservice/getPreferences", JSON.stringify({
                                              keys: ["region", "timeZone"]
                                          }), getPreferencesSuccess,
                           getPreferencesFailure)
    }

    function getPreferencesSuccess(message) {
        var response = JSON.parse(message.payload)

        if (response.region.countryCode !== undefined) {
            currentRegion = response.region.countryCode.toUpperCase()
        }

        if (response.timeZone !== undefined) {
            currentTimezone = response.timeZone
        }
		
        // now we can fetch all possible values and setup our model
        service.call("luna://com.palm.systemservice/getPreferenceValues", JSON.stringify({
                                                      key: "timeZone"
                                                  }), fetchAvailableTimezonesSuccess, fetchAvailableTimezonesFailure)

        function fetchAvailableTimezonesSuccess (message) {
                    var response = JSON.parse(message.payload)

                    timezoneModel.clear()
                    if (response.timeZone && response.timeZone.length > 0) {
                        for (var n = 0; n < response.timeZone.length; n++) {
                            var timezone = response.timeZone[n]
                            if (currentRegion === timezone.CountryCode) {
                                currentTimezoneIndex = n
                                //For countries with multiple timezones, we need to have the preferred one
                                if(timezone.preferred) {
                                    //Sometimes we have multiple preferred timezones per country, we need to make sure to pick the one with the right offset based on mcc
                                    if(timezone.offsetFromUTC === GlobalState.mccOffsetFromUTC) {
                                        currentTimezoneIndexPreferredOffset = n
                                    }
                                    //Otherwise just use the zone with the shortest offset compared to current MCC
                                    else {
                                        //Check if we already calculated a difference between a timezone and offset based on mcc
                                        if(currentDifference == -1){
                                            currentDifference = Math.abs(timezone.offsetFromUTC-GlobalState.mccOffsetFromUTC)
                                            currentTimezoneIndexPreferredTemp = n
                                        }
                                        //Check if the difference for the current timezone is less compared to the previous difference stored
                                        else if((timezone.offsetFromUTC-GlobalState.mccOffsetFromUTC)< currentDifference){
                                            currentDifference = Math.abs(timezone.offsetFromUTC-GlobalState.mccOffsetFromUTC)
                                            currentTimezoneIndexPreferredTemp = n
                                        }
                                    }
                                }
                            }

                            var offsetAdjustedTime = new Date();
                            offsetAdjustedTime.setMinutes(offsetAdjustedTime.getMinutes() + timezone.offsetFromUTC);

                            //Add each timezone to the model
                            timezoneModel.append({
                                                   timezoneCity: timezone.City,
                                                   timezoneDescription: timezone.Description,
                                                   timezoneCountryCode: timezone.CountryCode,
                                                   timezoneCountry: timezone.Country,
                                                   timezoneSupportsDST: timezone.supportsDST,
                                                   timezoneZoneID: timezone.ZoneID,
                                                   timezoneOffsetFromUTC: timezone.offsetFromUTC,
                                                   timezoneOffsetSign: timezone.offsetFromUTC.toString().substring(0,1) == "-" ? "-" : "+",
                                                   timezoneOffsetHours: timezone.offsetFromUTC.toString().substring(0,1) == "-" ? Math.floor(timezone.offsetFromUTC.toString().substring(1)/60) + ":" +(timezone.offsetFromUTC.toString().substring(1)%60+"00").substring(0,2): Math.floor(timezone.offsetFromUTC.toString()/60) + ":" +(timezone.offsetFromUTC.toString()%60+"00").substring(0,2),
                                                   timezonePreferred: timezone.preferred ? timezone.preferred : false,
                                                   timezoneoffsetAdjustedTime: " | "+Qt.formatDateTime(offsetAdjustedTime, "h:mm")
                                               })


                        }

                        //This is a bit nasty but it will help us to find the right timezone and store it.
                        var timezone2
                        //Take the closest match based on both country, mcc offset
                        if(currentTimezoneIndexPreferredOffset !== -1) {
                            timezone2 = response.timeZone[currentTimezoneIndexPreferredOffset]
                        }
                        //Otherwise find closest "preferred" based on mcc
                        else if(currentTimezoneIndexPreferredTemp !== -1) {
                            timezone2 = response.timeZone[currentTimezoneIndexPreferredTemp]
                        }
                        //Take any preferred that's available
                        else if(currentTimezoneIndexPreferred !== -1) {
                            timezone2 = response.timeZone[currentTimezoneIndexPreferred]
                        }
                        //Otherwise just the country one (for countries with a single one)
                        else {
                            timezone2 = response.timeZone[currentTimezoneIndex]
                        }

                        //Make sure to save the settings right away.
                        applySelectedTimezone(timezone2.City, timezone2.Description, timezone2.CountryCode, timezone2.Country, timezone2.supportsDST, timezone2.ZoneID, timezone2.offsetFromUTC, timezone2.preferred)
                    }

                    //Make sure we select the right one in the list

                    //Take the preferred one with smallest offset, regular prefered one or other available one
                    if(currentTimezoneIndexPreferredOffset !== -1)
					{
						finalIndex = currentTimezoneIndexPreferredOffset;
					}
					else if (currentTimezoneIndexPreferred !== -1)
					{
						finalIndex = currentTimezoneIndexPreferred
					}
					else
					{
                        finalIndex = Math.max(currentTimezoneIndexPreferredTemp, currentTimezoneIndex);
					}
					
					timezoneList.currentIndex = finalIndex
                    timezoneList.positionViewAtIndex(finalIndex, ListView.Center)
                    
                    filteredTimezoneModel.syncWithFilter();
                }
        function fetchAvailableTimezonesFailure (message) {
            console.log("Unable to fetch timezones")
                }
    }

    function getPreferencesFailure(message) {
        console.log("No regions found")
    }

    function applySelectedTimezone(timezoneCity, timezoneDescription, timezoneCountryCode, timezoneCountry, timezoneSupportsDST, timezoneZoneID, timezoneOffsetFromUTC, timezonePreferred) {
        var request = {
            timeZone: {
                "City": timezoneCity,
                "Description": timezoneDescription,
                "CountryCode": timezoneCountryCode,
                "Country": timezoneCountry,
                "supportsDST": timezoneSupportsDST,
                "ZoneID": timezoneZoneID,
                "offsetFromUTC": timezoneOffsetFromUTC,
                "preferred": true
            }
        }
        service.call("luna://com.palm.systemservice/setPreferences", JSON.stringify(request), setPreferencesSuccess, setPreferencesFailure)

        function setPreferencesSuccess (message) {
            console.log("setPreferencesSuccess")
                }

        function setPreferencesFailure (message) {
            console.log("Herrie setPreferencesFailure")
                }
    }

    ListModel {
        id: timezoneModel
    }

    ListModel {
        id: filteredTimezoneModel

        property string filter: filterTextField.text
        onFilterChanged: syncWithFilter();

        function syncWithFilter() {
            filteredTimezoneModel.clear()
            for( var i = 0; i < timezoneModel.count; ++i ) {
                var timezoneItem = timezoneModel.get(i);
                var filterLowered = filter.toLowerCase();
                if( filterLowered.length === 0 ||
                    timezoneItem.timezoneCountry.toLowerCase().indexOf(filterLowered) >= 0 ||
                    timezoneItem.timezoneCity.toLowerCase().indexOf(filterLowered) >= 0 )
                {
                    filteredTimezoneModel.append(timezoneItem);
                }
            }
			timezoneList.currentIndex = finalIndex
            timezoneList.positionViewAtIndex(finalIndex, ListView.Center)

        }
    }

    Column {
        id: column
        anchors.fill: content
        spacing: Units.gu(5)

        TextField {
            id: filterTextField
            placeholderText: "Filter list..."
            height: Units.gu(4)
            font.pixelSize: Units.gu(36/13.5)
        }

        ListView {
            id: timezoneList
            anchors.left: parent.left
            anchors.right: parent.right
            height: column.height - column.spacing - filterTextField.height
            snapMode: ListView.SnapToItem	

            clip: true

            model: filteredTimezoneModel

            delegate: MouseArea {
                id: delegate

                anchors.right: parent.right
                anchors.left: parent.left
                height: Math.max(tzCountry.height+tzCity.height,
                                 tzDescription.height+tzOffset.height,
                                 tzCountry.height+tzDescription.height) + Units.gu(3.0)

                Text {
                    id: tzCountry
                    width: parent.width / 2
                    anchors.top: parent.top
                    anchors.topMargin: Units.gu(1.5)
                    anchors.left: parent.left
                    color: delegate.ListView.isCurrentItem ? "white" : "#6e83a3"
                    font.pixelSize: Units.gu(36/13.5) // 1/13.5 = 1/72*96/18
                    text: timezoneCountry
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: tzCity
                    width: parent.width / 2
                    anchors.top: tzCountry.bottom
                    color: delegate.ListView.isCurrentItem ? "white" : "#6e83a3"
                    font.pixelSize: Units.gu(22/13.5)
                    text: timezoneCity
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: tzOffset
                    width: content.width
                    anchors.verticalCenter: tzTime.verticalCenter
                    anchors.rightMargin: Units.gu(0.3)
                    anchors.right: tzTime.left
                    color: delegate.ListView.isCurrentItem ? "white" : "#6e83a3"
                    font.pixelSize: Units.gu(22/13.5)
                    text: timezoneOffsetHours==="0:00" ? "UTC " : "UTC " + timezoneOffsetSign + timezoneOffsetHours
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.NoWrap
                }
                Text {
                    id: tzTime
                    anchors.top: tzCountry.top
                    anchors.right: parent.right
                    color: delegate.ListView.isCurrentItem ? "white" : "#6e83a3"
                    font.pixelSize: Units.gu(36/13.5)
                    text: timezoneoffsetAdjustedTime
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: tzDescription
                    width: parent.width / 2
                    anchors.top: tzCity.top
                    anchors.right: parent.right
                    color: delegate.ListView.isCurrentItem ? "white" : "#6e83a3"
                    font.pixelSize: Units.gu(22/13.5)
                    text: timezoneDescription
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    id: dividerRectangleTop
                    color: "#1e3355"
                    width: parent.width
                    height: Units.gu(1 / 10)
                    anchors.top: parent.top
                }
                Rectangle {
                    id: dividerRectangleBottom
                    color: "#1e3355"
                    width: parent.width
                    height: Units.gu(1 / 10)
                    anchors.top: parent.bottom
                }

                onClicked: {
                    timezoneList.currentIndex = index
                    applySelectedTimezone(timezoneCity, timezoneDescription, timezoneCountryCode, timezoneCountry, timezoneSupportsDST, timezoneZoneID, timezoneOffsetFromUTC, timezonePreferred)
                }
            }
        }
    }

    Component {
        id: forwardButton
        StackButton {
            text: "Next"
            onClicked: {
                pageStack.next()
            }
        }
    }
}
