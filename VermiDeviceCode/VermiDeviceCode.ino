#define ENABLE_USER_AUTH
#define ENABLE_DATABASE

#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ESPmDNS.h>
#include <WiFiClientSecure.h>
#include <FirebaseClient.h>
#include <time.h>
#include <NetworkUdp.h>
#include <ArduinoOTA.h>

const char* DEVICE_ID = "1934"; // your device id here

// AP credentials
const char* ap_ssid = "Vermi_Compost_1934";
const char* mdnshost = "vermi1934";

WiFiServer telnetServer(23); // Default Telnet port
WiFiClient telnetClient;
// IP for AP
IPAddress local_IP(10, 0, 0, 1);
IPAddress gateway(10, 0, 0, 1);
IPAddress subnet(255, 255, 255, 0);

WebServer server(80);
Preferences preferences;

bool apDisablePending = false;   // Flag to start AP disable timer
unsigned long apDisableStart = 0; // Timestamp when timer starts

// DS18B20 setup
#define ONE_WIRE_BUS 13
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
DeviceAddress tempDeviceAddress;

//Sensors
#define MOISTURE_SENSOR_1 32
#define MOISTURE_SENSOR_2 33
#define WATER_LEVEL_TRIG 14
#define WATER_LEVEL_ECHO 27
#define SOUND_SPEED 0.034
#define PUMP_RELAY 25

//Firebase
#define API_KEY "FIREBASE_API_KEY"
#define FIREBASE_PROJECT_ID "PROJECT_ID"
#define DATABASE_URL "FIREBASE_REALTIME_DATABASE_URL"
#define USER_EMAIL "EMAIL_MUST_BE_IN_AUTHENTICATIONS"
#define USER_PASSWORD "PASSWORD_MUST_BE_IN_AUTHENTICATIONS"

void asyncCB(AsyncResult &aResult);
void processData(AsyncResult &aResult);

UserAuth user_auth(API_KEY, USER_EMAIL, USER_PASSWORD);

FirebaseApp app;

WiFiClientSecure ssl_client1, ssl_client2;

using AsyncClient = AsyncClientClass;
AsyncClient async_client1(ssl_client1), async_client2(ssl_client2);

RealtimeDatabase Database;

AsyncResult dbResult;


int valAir1 = 3018;
int valWater1 = 1710;
int valAir2 = 3018;
int valWater2 = 1710;

float Tankempty = 10;
float TankFull = 3;

bool setUpComplete = false;

bool pumpActive = false;
unsigned long pumpStartTime = 0;
unsigned long lastPumpOffTime = 0;

const unsigned long pumpDuration = 5000;        // 5 seconds
const unsigned long pumpCooldown = 30000;  

unsigned long lastSendTime = 0;
const unsigned long sendInterval = 30000;

unsigned long lastUpload = 0;
const unsigned long uploadInterval = 110000;

unsigned long lastSensorRead = 0;
const unsigned long sensorReadInvterval = 1000;

bool firebaseBusy = false;

float temp0 = 0, temp1 = 0;
int m1 = 0, m2 = 0;
int m1_percent = 0, m2_percent = 0;
float ultrasonicDistance = 0;
float waterLevel = 0;

String getUnixTimeString() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "0";  // Or "" or any fallback you prefer if time not available
  }
  time_t unixTime = mktime(&timeinfo);
  if (unixTime == -1) {
    return "0";  // fallback in case mktime fails
  }
  return String(unixTime);
}
void loadOrSetDefaults() {
  preferences.begin("config", true);

  // Load or initialize integer values
  valAir1 = preferences.getInt("valAir1", 3018);

  valWater1 = preferences.getInt("valWater1", 1710);

  valAir2 = preferences.getInt("valAir2", 3018);

  valWater2 = preferences.getInt("valWater2", 1710);

  Tankempty = preferences.getFloat("Tankempty", 10.0);

  TankFull = preferences.getFloat("TankFull", 3.0);
  
  setUpComplete = preferences.getBool("setUpComplete", false);

  preferences.end();
}

void readSensor(){
  sensors.requestTemperatures();

  temp0 = NAN, temp1 = NAN;
  DeviceAddress tempDeviceAddress;

  if (sensors.getAddress(tempDeviceAddress, 0)) {
    temp0 = sensors.getTempC(tempDeviceAddress);
  }
  if (sensors.getAddress(tempDeviceAddress, 1)) {
    temp1 = sensors.getTempC(tempDeviceAddress);
  }

  m1 = analogRead(MOISTURE_SENSOR_1);
  m2 = analogRead(MOISTURE_SENSOR_2);

  m1_percent = toPercent(m1,valAir1, valWater1);
  m2_percent = toPercent(m2,valAir2, valWater2);

  digitalWrite(WATER_LEVEL_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(WATER_LEVEL_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(WATER_LEVEL_TRIG, LOW);

  long duration = pulseIn(WATER_LEVEL_ECHO, HIGH);

  float distanceCm = duration * SOUND_SPEED / 2;

  ultrasonicDistance = distanceCm;

  waterLevel = toPercent(distanceCm,Tankempty,TankFull);

  if (telnetClient && telnetClient.connected()) {

  }
  
    telnetClient.print("Temperature 1: ");
    telnetClient.print(String(temp0));
    telnetClient.print("Temperature 2: ");
    telnetClient.print(String(temp1));
    telnetClient.print("Moisture 1: ");
    telnetClient.print(String(m1));
    telnetClient.print("Moisture 2: ");
    telnetClient.print(String(m2));
    telnetClient.print("Water Level: ");
    telnetClient.print(String(waterLevel));
    telnetClient.print("Distance Cm: ");
    telnetClient.println(String(distanceCm));
}

void handleCalibration() {
  if (!server.hasArg("target")) {
    server.send(400, "text/plain", "Missing target or value");
    return;
  }

  String target = server.arg("target");

  preferences.begin("config", false);

  if (target == "moisture_dry") {

    preferences.putInt("valAir1", m1);
    preferences.putInt("valAir2", m2);
    valAir1 = m1;
    valAir2 = m2;
    server.send(200, "text/plain", "Moisture dry calibrated.");
  } else if (target == "moisture_wet") {
    preferences.putInt("valWater1", m1);
    preferences.putInt("valWater2", m2);
    valWater1 = m1; 
    valWater2 = m2;
    server.send(200, "text/plain", "Moisture wet calibrated.");
  } else if (target == "tankempty") {

    preferences.putFloat("Tankempty", ultrasonicDistance);

    Tankempty = ultrasonicDistance;
    server.send(200, "text/plain", "Tank empty calibrated.");
  } else if (target == "tankfull") {
    preferences.putFloat("TankFull", ultrasonicDistance);
    if(!setUpComplete){
      preferences.putBool("setUpComplete", true);
      setUpComplete = true;
    }
    TankFull = ultrasonicDistance;
    server.send(200, "text/plain", "Tank full calibrated.");
  } else {
    server.send(400, "text/plain", "Unknown target.");
  }

  preferences.end();
}

                                                   
void connectWithSavedCredentials() {
  preferences.begin("wifi", true); // read-only
  String saved_ssid = preferences.getString("ssid", "");
  String saved_password = preferences.getString("password", "");
  preferences.end();

  if (saved_ssid.length() > 0) {
    Serial.printf("Connecting with saved credentials: %s\n", saved_ssid.c_str());
    WiFi.mode(WIFI_STA);
    WiFi.begin(saved_ssid.c_str(), saved_password.c_str());

    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
      delay(500);
      Serial.print(".");
      retries++;
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("Connected to WiFi with saved credentials.");
      Serial.print("STA IP: ");
      Serial.println(WiFi.localIP());


      ArduinoOTA.setPassword("VermiDev1929");
      ArduinoOTA
      .onStart([]() {
        String type;
        if (ArduinoOTA.getCommand() == U_FLASH) {
          type = "sketch";

          if (telnetClient && telnetClient.connected()) {
            telnetClient.println("OTA update starting, disconnecting Telnet...");
            telnetClient.stop();
          }

        } else {  // U_SPIFFS
          type = "filesystem";
        }

        // NOTE: if updating SPIFFS this would be the place to unmount SPIFFS using SPIFFS.end()
        Serial.println("Start updating " + type);
      })
      .onEnd([]() {
        Serial.println("\nEnd");
      })
      .onProgress([](unsigned int progress, unsigned int total) {
        Serial.printf("Progress: %u%%\r", (progress / (total / 100)));
      })
      .onError([](ota_error_t error) {
        Serial.printf("Error[%u]: ", error);
        if (error == OTA_AUTH_ERROR) {
          Serial.println("Auth Failed");
        } else if (error == OTA_BEGIN_ERROR) {
          Serial.println("Begin Failed");
        } else if (error == OTA_CONNECT_ERROR) {
          Serial.println("Connect Failed");
        } else if (error == OTA_RECEIVE_ERROR) {
          Serial.println("Receive Failed");
        } else if (error == OTA_END_ERROR) {
          Serial.println("End Failed");
        }
      });

      ArduinoOTA.begin();

      telnetServer.begin();
      telnetServer.setNoDelay(true);
    } else {
      Serial.println("Failed to connect with saved credentials.");
      //Temporary code so I can manually reset it
      WiFi.mode(WIFI_AP);
      WiFi.softAPConfig(local_IP, gateway, subnet);
      WiFi.softAP(ap_ssid);
    }
  } else {
    Serial.println("No saved WiFi credentials found.");
  }
}

void handlePing() {
  // Send a 200 OK status with no content
  server.send(200, "text/plain", "");
}

void handleHandshake() {
  String json = "{\"device_id\": \"" + String(DEVICE_ID) + 
                "\", \"device_mdns\": \"" + String(mdnshost) + 
                "\", \"device_name\": \"" + String(ap_ssid) + "\"}";
  server.send(200, "application/json", json);
}

void handleConnectToNetwork() {
  if (!server.hasArg("ssid") || !server.hasArg("password")) {
    server.send(400, "text/plain", "Missing ssid or password");
    return;
  }

  String ssid = server.arg("ssid");
  String password = server.arg("password");

  Serial.printf("Connecting to WiFi SSID: %s\n", ssid.c_str());

  WiFi.mode(WIFI_AP_STA);
  WiFi.enableAP(true);
  WiFi.begin(ssid.c_str(), password.c_str());

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 20) {
    delay(500);
    Serial.print(".");
    retries++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected successfully.");
    Serial.print("STA IP: ");
    Serial.println(WiFi.localIP());

    preferences.begin("wifi", false);
    preferences.putString("ssid", ssid);
    preferences.putString("password", password);
    preferences.end();

    server.send(200, "text/plain", "success");
    apDisablePending = true;
    apDisableStart = millis();
  } else {
    Serial.println("WiFi connection failed.");
    server.send(200, "text/plain", "failed");
  }
}

void handleConfirm() {
  Serial.println("Disabling AP mode...");
  WiFi.softAPdisconnect(true);
  server.send(200, "text/plain", "AP disabled");
}

void handleResetWifi() {
  preferences.begin("wifi", false);
  preferences.clear();
  preferences.end();

  // Clear "config" namespace
  preferences.begin("config", false);
  preferences.clear();
  preferences.end();

  Serial.println("WiFi credentials cleared from preferences.");

  WiFi.disconnect(true);
  delay(1000);

  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(local_IP, gateway, subnet);
  WiFi.softAP(ap_ssid);

  Serial.println("AP restarted after reset.");
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.send(200, "text/plain", "WiFi credentials reset and AP re-enabled");
  ESP.restart();

}

void handleGetData() {

  String json = "{";
  json += "\"temp0\":" + String(temp0, 2) + ",";
  json += "\"temp1\":" + String(temp1, 2) + ",";
  json += "\"moisture1\":" + String(m1_percent) + ",";
  json += "\"moisture2\":" + String(m2_percent) + ",";
  json += "\"water_level\":" + String(waterLevel);
  json += "}";

  server.send(200, "application/json", json);
}


void setup() {
  Serial.begin(115200);

  pinMode(WATER_LEVEL_TRIG, OUTPUT); 
  pinMode(WATER_LEVEL_ECHO, INPUT);
  pinMode(PUMP_RELAY, OUTPUT);
  digitalWrite(PUMP_RELAY, HIGH);
  // Try to connect with saved credentials first
  connectWithSavedCredentials();
  loadOrSetDefaults();

  // If not connected, start AP mode for configuration
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Starting AP mode for WiFi configuration...");

    // Configure AP IP
    WiFi.softAPConfig(local_IP, gateway, subnet);

    // Start AP
    WiFi.softAP(ap_ssid);
    Serial.println("AP started");
    Serial.print("AP IP: ");
    Serial.println(WiFi.softAPIP());


    server.on("/handshake", HTTP_GET, handleHandshake);
    server.on("/connect_to_network", HTTP_GET, handleConnectToNetwork);
    server.on("/confirm", HTTP_GET, handleConfirm);

    Serial.println("HTTP server started");


  } else {
    Serial.println("WiFi connected, skipping AP mode.");
    configTime(8 * 3600, 0, "pool.ntp.org", "time.nist.gov");
    ssl_client1.setInsecure();
    ssl_client2.setInsecure();

    // Set timeout
    ssl_client1.setConnectionTimeout(1000);
    ssl_client1.setHandshakeTimeout(5);
    ssl_client2.setConnectionTimeout(1000);
    ssl_client2.setHandshakeTimeout(5);

    initializeApp(async_client1, app, getAuth(user_auth), processData, "🔐 authTask");

    // Step 9
    app.getApp<RealtimeDatabase>(Database);

    // Step 10
    Database.url(DATABASE_URL);
  }
  server.on("/calibrate",HTTP_GET, handleCalibration);

  server.on("/reset_wifi", HTTP_GET, handleResetWifi);
  server.on("/get_data", HTTP_GET, handleGetData);
  server.on("/ping", HTTP_GET, handlePing);

  server.begin();
  sensors.begin();

  if (!MDNS.begin(mdnshost)) {
    Serial.println("Error setting up MDNS responder!");
  } else {
    Serial.println("mDNS responder started: http://" + String(mdnshost) + ".local");
  }

}

void loop() {
  if(WiFi.status() == WL_CONNECTED){
    ArduinoOTA.handle();

    if (telnetServer.hasClient()) {
      if (!telnetClient || !telnetClient.connected()) {
        if (telnetClient) telnetClient.stop();
        telnetClient = telnetServer.available();
        Serial.println("New Telnet client connected");
        telnetClient.println("Welcome to ESP32 Telnet server!");
      } else {
        WiFiClient newClient = telnetServer.available();
        newClient.println("Only one client at a time is allowed.");
        newClient.stop();
      }
    }
  }
  server.handleClient();

  app.loop();

  unsigned long currentTime = millis();
  if (apDisablePending) {
    // Check if 10 seconds have passed
    if (currentTime - apDisableStart >= 30000) {
      Serial.println("Disabling AP mode after 30 seconds delay...");
      WiFi.softAPdisconnect(true); // Disable AP
      apDisablePending = false;    // Reset flag
      ESP.restart();
    }
  }
  
  if(currentTime - lastSensorRead >= sensorReadInvterval){
    lastSensorRead = currentTime;
    readSensor();
  }
  if(setUpComplete){
    if(app.ready()){
      String currentTimeStamp = getUnixTimeString();
      if(currentTime - lastUpload >= uploadInterval){
        lastUpload = currentTime;
        uploadRecordDataToFirebase(currentTimeStamp,temp0, temp1, m1_percent, m2_percent, waterLevel);
      }
      else if (currentTime - lastSendTime >= sendInterval){
        Serial.println("Timestamp: " + currentTimeStamp);
        lastSendTime = currentTime;
        uploadDataToFirebase(temp0, temp1, m1_percent, m2_percent, waterLevel);
      }
    }
    if (!pumpActive && (currentTime - lastPumpOffTime >= pumpCooldown)) {
      if ((temp0+temp1)/2 > 34 || (m1_percent+m2_percent)/2 < 80) {
        digitalWrite(PUMP_RELAY, LOW);
        pumpStartTime = currentTime;
        pumpActive = true;
        Serial.println("Pump ON");
        telnetClient.println("Pump On");

      }
    }
    if (pumpActive && (currentTime - pumpStartTime >= pumpDuration)) {
      digitalWrite(PUMP_RELAY, HIGH);
      pumpActive = false;
      lastPumpOffTime = currentTime;
      Serial.println("Pump OFF, cooldown started");
      telnetClient.println("Pump Off");
    }
  }
}


int toPercent(int val, int minVal, int maxVal) {
  int percent = map(val, maxVal, minVal, 100, 0);
  return constrain(percent, 0, 100);
}

void uploadDataToFirebase(float temp0, float temp1, int moisture1, int moisture2, float waterLevel) {
  if (!app.ready() || firebaseBusy) {
    Serial.println("Firebase not ready, skipping upload.");
    return;
  }
  firebaseBusy = true;
  Serial.println("Sending realtime");
  Database.set<float>(async_client1, (String("/RealTimeData/") + DEVICE_ID + "/temp0").c_str(), temp0, processData, "RTDB_Send_Float");
  Database.set<float>(async_client1, (String("/RealTimeData/") + DEVICE_ID + "/temp1").c_str(), temp1, processData, "RTDB_Send_Float");
  Database.set<int>(async_client1, (String("/RealTimeData/") + DEVICE_ID + "/moisture1").c_str(), moisture1, processData, "RTDB_Send_Int");
  Database.set<int>(async_client1, (String("/RealTimeData/") + DEVICE_ID + "/moisture2").c_str(), moisture2, processData, "RTDB_Send_Int");
  Database.set<float>(async_client1, (String("/RealTimeData/") + DEVICE_ID + "/water_level").c_str(), waterLevel, processData, "RTDB_Send_Float");

}
void uploadRecordDataToFirebase(String date ,float temp0, float temp1, int moisture1, int moisture2, float waterLevel){
  if (!app.ready() || firebaseBusy) {
    Serial.println("Firebase not ready, skipping upload.");
    return;
  }
  firebaseBusy = true;
  Serial.println("Sending Record");

  Database.set<float>(async_client2, (String("/RecordsData/") + DEVICE_ID +"/" +String(date) + "/temp0").c_str(), temp0, processData, "RTDB_Send_Float");
  Database.set<float>(async_client2, (String("/RecordsData/") + DEVICE_ID +"/" +String(date) + "/temp1").c_str(), temp1, processData, "RTDB_Send_Float");
  Database.set<int>(async_client2, (String("/RecordsData/") + DEVICE_ID   +"/" +String(date) + "/moisture1").c_str(), moisture1, processData, "RTDB_Send_Int");
  Database.set<int>(async_client2, (String("/RecordsData/") + DEVICE_ID   +"/" +String(date) + "/moisture2").c_str(), moisture2, processData, "RTDB_Send_Int");
  Database.set<float>(async_client2, (String("/RecordsData/") + DEVICE_ID +"/" +String(date) + "/water_level").c_str(), waterLevel, processData, "RTDB_Send_Float");
}


void processData(AsyncResult &aResult)
{
    // Exits when no result available when calling from the loop.
    if (!aResult.isResult())
        return;

    if (aResult.isEvent())
        Firebase.printf("Event task: %s, msg: %s, code: %d\n", aResult.uid().c_str(), aResult.eventLog().message().c_str(), aResult.eventLog().code());

    if (aResult.isDebug())
        Firebase.printf("Debug task: %s, msg: %s\n", aResult.uid().c_str(), aResult.debug().c_str());

    if (aResult.isError())
        Firebase.printf("Error task: %s, msg: %s, code: %d\n", aResult.uid().c_str(), aResult.error().message().c_str(), aResult.error().code());

    if (aResult.available())
        Firebase.printf("task: %s, payload: %s\n", aResult.uid().c_str(), aResult.c_str());

    firebaseBusy = false;
}