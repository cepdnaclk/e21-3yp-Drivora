#include <Arduino.h>

#define TRIGPIN 3
#define ECHOPIN 4

const int sampleSize = 3;
float readings[sampleSize];

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
      readings[validCount] = duration / 58.2;
      validCount++;
    }

    delay(40);
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

  float qualityDistance = readings[validCount / 2];

  if (qualityDistance > 500.0f) {
    return -1.0f;
  }

  return qualityDistance;
}

void setup() {
  Serial.begin(9600);
  pinMode(TRIGPIN, OUTPUT);
  pinMode(ECHOPIN, INPUT);

  digitalWrite(TRIGPIN, LOW);
  delay(1000);

  Serial.println("JSN-SR04T-V3.3 | Quality Mode Active");
}

void loop() {
  float d = readQualityDistanceCm();

  if (d < 0) {
    Serial.println("Sensor Timeout: No Echo received.");
  } else {
    Serial.print("Distance: ");
    Serial.print(d);
    Serial.println(" cm");
  }

  delay(150);
}