#include <Wire.h>
#include <MPU6050.h>

MPU6050 mpu;

// ================= PARAMETERS =================
const int VEHICLE_TYPE = 3;

float trackWidth_m = 1.90f;
float vehicleHeight_m = 3.20f;
int loadCondition = 2;
int suspensionType = 0;

// ================= CALIB =================
float axBias=0, ayBias=0, azBias=0;
float gxBias=0, gyBias=0, gzBias=0;

float pitchZero=0, rollZero=0;

// ================= STATE =================
float pitchAngle=0, rollAngle=0;
float pitchDisplay=0, rollDisplay=0;

unsigned long lastMicros;
unsigned long lastRiskChangeMs;

// ================= VEHICLE MODEL =================
float criticalRollDeg=30;
float criticalPitchDeg=20;
float vehicleFactor=1.0;

// ================= TUNING (UPDATED) =================
const float alphaStill = 0.90f;
const float alphaMotion = 0.9995f;

const float accelWarn = 0.02f;
const float accelHigh = 0.08f;

const float displayAlpha = 0.82f;
const float deadband = 0.06f;

const unsigned long riskHoldMs = 250;

// ================= OUTPUT =================
float riskScore = 0;
int stableRisk = 0;

// ================= HELPERS =================
float clampf(float x,float lo,float hi){
  if(x<lo) return lo;
  if(x>hi) return hi;
  return x;
}

float mapAlpha(float err){
  if(err <= accelWarn) return alphaStill;
  if(err >= accelHigh) return alphaMotion;
  float t = (err-accelWarn)/(accelHigh-accelWarn);
  return alphaStill + t*(alphaMotion-alphaStill);
}

int riskLevel(float s){
  if(s<0.35) return 0;
  if(s<0.6) return 1;
  if(s<0.8) return 2;
  return 3;
}

// ================= VEHICLE =================
void computeVehicle(){
  float base;
  switch(VEHICLE_TYPE){
    case 1: base=0.32; vehicleFactor=0.9; break;
    case 2: base=0.42; vehicleFactor=1.1; break;
    case 3: base=0.40; vehicleFactor=1.15; break;
    default: base=0.40; vehicleFactor=1.0;
  }

  float loadF = (loadCondition==2)?1.12:(loadCondition==1)?1.0:0.92;
  float suspF = (suspensionType==0)?1.05:1.0;

  float cogH = vehicleHeight_m * base * loadF;
  criticalRollDeg = atan(trackWidth_m/(2*cogH))*180.0/PI;

  criticalPitchDeg = 20;
  vehicleFactor *= suspF;
}

// ================= CALIB =================
void calibrate(){
  Serial.println("Keep still...");
  long ax=0,ay=0,az=0,gx=0,gy=0,gz=0;

  for(int i=0;i<1000;i++){
    int16_t a,b,c,d,e,f;
    mpu.getMotion6(&a,&b,&c,&d,&e,&f);
    ax+=a; ay+=b; az+=c;
    gx+=d; gy+=e; gz+=f;
    delay(2);
  }

  axBias=ax/1000.0;
  ayBias=ay/1000.0;
  azBias=(az/1000.0)-16384;

  gxBias=gx/1000.0;
  gyBias=gy/1000.0;
  gzBias=gz/1000.0;

  float ax0=axBias/16384.0;
  float ay0=ayBias/16384.0;
  float az0=(azBias+16384)/16384.0;

  pitchZero = atan2(ax0,sqrt(ay0*ay0+az0*az0))*180/PI;
  rollZero  = -atan2(ay0,sqrt(ax0*ax0+az0*az0))*180/PI;

  Serial.println("Done");
}

// ================= SETUP =================
void setup(){
  Serial.begin(921600);

  Wire.begin(8,9);
  Wire.setClock(400000);

  mpu.initialize();
  mpu.setDLPFMode(MPU6050_DLPF_BW_20);

  if(!mpu.testConnection()){
    Serial.println("MPU fail");
    while(1);
  }

  computeVehicle();
  calibrate();

  lastMicros = micros();
  lastRiskChangeMs = millis();

  Serial.println("roll,pitch,confidence,riskScore,riskLevel,accMag");
}

// ================= LOOP =================
void loop(){

  int16_t axR,ayR,azR,gxR,gyR,gzR;
  mpu.getMotion6(&axR,&ayR,&azR,&gxR,&gyR,&gzR);

  float dt = (micros()-lastMicros)/1000000.0;
  lastMicros = micros();
  if(dt<=0 || dt>0.1) dt=0.01;

  float ax=(axR-axBias)/16384.0;
  float ay=(ayR-ayBias)/16384.0;
  float az=(azR-azBias)/16384.0;

  float gx=(gxR-gxBias)/131.0;
  float gy=(gyR-gyBias)/131.0;

  float accMag = sqrt(ax*ax+ay*ay+az*az);
  float accErr = fabs(accMag-1.0);

  // accel tilt
  float pitchAcc = atan2(ax,sqrt(ay*ay+az*az))*180/PI - pitchZero;
  float rollAcc  = -atan2(ay,sqrt(ax*ax+az*az))*180/PI - rollZero;

  // gyro integrate
  float pitchGyro = pitchAngle + gy*dt;
  float rollGyro  = rollAngle  + gx*dt;

  // ================= KEY FIX: HIGH-DYNAMICS OVERRIDE =================
  float angRate = max(fabs(gx), fabs(gy));

  float alpha;

  if(angRate > 8.0f && accErr > 0.02f){
    alpha = 0.9997f;
  } else {
    alpha = mapAlpha(accErr);
  }

  // fusion
  pitchAngle = alpha*pitchGyro + (1-alpha)*pitchAcc;
  rollAngle  = alpha*rollGyro  + (1-alpha)*rollAcc;

  // display smoothing (faster now)
  pitchDisplay = displayAlpha*pitchAngle + (1-displayAlpha)*pitchDisplay;
  rollDisplay  = displayAlpha*rollAngle  + (1-displayAlpha)*rollDisplay;

  if(fabs(pitchDisplay)<deadband) pitchDisplay=0;
  if(fabs(rollDisplay)<deadband) rollDisplay=0;

  // ================= CONFIDENCE =================
  float confidence = 1.0 - clampf((accErr-0.02)/0.18,0,1);

  // ================= RISK =================
  float nRoll  = fabs(rollDisplay)/criticalRollDeg;
  float nPitch = fabs(pitchDisplay)/criticalPitchDeg;

  float baseRisk = vehicleFactor*(0.6*nRoll + 0.4*nPitch);
  baseRisk = clampf(baseRisk,0,1);

  float effectiveRisk = baseRisk*(0.7 + 0.3*confidence);

  int desired = riskLevel(effectiveRisk);
  unsigned long now = millis();

  if(desired!=stableRisk){
    if(now-lastRiskChangeMs>riskHoldMs){
      stableRisk=desired;
      lastRiskChangeMs=now;
    }
  }else lastRiskChangeMs=now;

  // ================= OUTPUT =================
  Serial.print(rollDisplay,3); Serial.print(",");
  Serial.print(pitchDisplay,3); Serial.print(",");
  Serial.print(confidence,3); Serial.print(",");
  Serial.print(effectiveRisk,3); Serial.print(",");
  Serial.print(stableRisk); Serial.print(",");
  Serial.println(accMag,3);

  delay(8);
}