#include <Arduino.h>

#define TRIGPIN 3
#define ECHOPIN 4

// ================= DISTANCE SETTINGS =================
const float MIN_VALID_CM = 25.0f;
const float MAX_VALID_CM = 250.0f;

const float OBJECT_ZONE_CM   = 180.0f;
const float WARNING_ZONE_CM  = 80.0f;

// ================= SAMPLING =================
const int sampleSize = 2;
float readings[sampleSize];

// ================= FILTERING =================
float filteredDistance = -1.0f;
float prevFilteredDistance = -1.0f;

// Faster response than before
const float distanceFilterAlpha = 0.55f;

// ================= APPROACH DETECTION =================
const float APPROACH_DELTA_CM = 2.0f;

int approachCounter = 0;
int warningCounter = 0;
const int APPROACH_CONFIRM_COUNT = 1;
const int WARNING_CONFIRM_COUNT  = 1;

// ================= OUTPUT STATE =================
enum FCWState {
  CLEAR = 0,
  OBJECT_AHEAD = 1,
  APPROACHING = 2,
  WARNING = 3
};

FCWState currentState = CLEAR;

const char* stateName(FCWState s) {
  switch (s) {
    case CLEAR: return "CLEAR";
    case OBJECT_AHEAD: return "OBJECT_AHEAD";
    case APPROACHING: return "APPROACHING";
    case WARNING: return "WARNING";
    default: return "CLEAR";
  }
}

// ================= READ DISTANCE =================
float readQualityDistanceCm() {
  int validCount = 0;

  for (int i = 0; i < sampleSize; i++) {
    digitalWrite(TRIGPIN, LOW);
    delayMicroseconds(5);
    digitalWrite(TRIGPIN, HIGH);
    delayMicroseconds(20);
    digitalWrite(TRIGPIN, LOW);

    long duration = pulseIn(ECHOPIN, HIGH, 40000);

    if (duration > 0) {
      readings[validCount] = duration / 58.2f;
      validCount++;
    }

    delay(15);
  }

  if (validCount == 0) {
    return -1.0f;
  }

  for (int i = 0; i < validCount - 1; i++) {
    for (int j = i + 1; j < validCount; j++) {
      if (readings[i] > readings[j]) {
        float temp = readings[i];
        readings[i] = readings[j];
        readings[j] = temp;
      }
    }
  }

  float medianDistance = readings[validCount / 2];

  if (medianDistance < MIN_VALID_CM || medianDistance > MAX_VALID_CM) {
    return -1.0f;
  }

  return medianDistance;
}

// ================= FILTER =================
float updateFilteredDistance(float rawDistance) {
  if (rawDistance < 0) {
    filteredDistance = -1.0f;
    return -1.0f;
  }

  if (filteredDistance < 0) {
    filteredDistance = rawDistance;
  } else {
    filteredDistance =
      distanceFilterAlpha * rawDistance +
      (1.0f - distanceFilterAlpha) * filteredDistance;
  }

  return filteredDistance;
}

// ================= FCW LOGIC =================
void updateFCWState(float dist) {
  if (dist < 0) {
    currentState = CLEAR;
    approachCounter = 0;
    warningCounter = 0;
    prevFilteredDistance = -1.0f;
    return;
  }

  float delta = 0.0f;
  bool approaching = false;

  if (prevFilteredDistance > 0) {
    delta = prevFilteredDistance - dist;   // positive means getting closer
    if (delta > APPROACH_DELTA_CM) {
      approaching = true;
    }
  }

  prevFilteredDistance = dist;

  if (approaching) {
    if (approachCounter < APPROACH_CONFIRM_COUNT) approachCounter++;
  } else {
    if (approachCounter > 0) approachCounter--;
  }

  bool confirmedApproaching = (approachCounter >= APPROACH_CONFIRM_COUNT);

  if (dist <= WARNING_ZONE_CM && confirmedApproaching) {
    if (warningCounter < WARNING_CONFIRM_COUNT) warningCounter++;
  } else {
    if (warningCounter > 0) warningCounter--;
  }

  bool confirmedWarning = (warningCounter >= WARNING_CONFIRM_COUNT);

  if (confirmedWarning) {
    currentState = WARNING;
  } else if (confirmedApproaching && dist <= OBJECT_ZONE_CM) {
    currentState = APPROACHING;
  } else if (dist <= OBJECT_ZONE_CM) {
    currentState = OBJECT_AHEAD;
  } else {
    currentState = CLEAR;
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(9600);

  pinMode(TRIGPIN, OUTPUT);
  pinMode(ECHOPIN, INPUT);

  digitalWrite(TRIGPIN, LOW);
  delay(1000);

  Serial.println("JSN-SR04T FCW Prototype Started");
}

// ================= LOOP =================
void loop() {
  float rawDistance = readQualityDistanceCm();
  float smoothedDistance = updateFilteredDistance(rawDistance);

  updateFCWState(smoothedDistance);

  Serial.print("Raw: ");
  if (rawDistance < 0) Serial.print("Invalid");
  else Serial.print(rawDistance, 1);

  Serial.print(" cm | Filtered: ");
  if (smoothedDistance < 0) Serial.print("Invalid");
  else Serial.print(smoothedDistance, 1);

  Serial.print(" cm | State: ");
  Serial.println(stateName(currentState));

  delay(40);
}