import 'package:flutter/material.dart';

enum AlertSeverity { info, warning, danger, critical }

class SafetyAlert {
  final String title;
  final String message;
  final AlertSeverity severity;
  final String unitSource;
  final DateTime timestamp;

  SafetyAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.unitSource,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class DrivoraSensorData {
  // Unit A: Front Radar (FCW)
  final double ttc; 
  final double frontDistance;
  
  // Unit B: Rear Hub (Side/Rear)
  final double blindSpotLeftDist;
  final double blindSpotRightDist;
  final double rearClearance;

  // Unit C: COG & Dynamics (Rollover)
  final double lateralG;
  final double tiltAngle;

  // Unit D: Windshield Hub (AI Vision / LDW)
  final bool ldwActive;
  final double lanePosition;
  
  // System Basics
  final double speed;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;
  
  // Unit Status
  final bool unitAOnline;
  final bool unitBOnline;
  final bool unitCOnline;
  final bool unitDOnline;

  DrivoraSensorData({
    this.ttc = 10.0,
    this.frontDistance = 100.0,
    this.blindSpotLeftDist = 15.0,
    this.blindSpotRightDist = 15.0,
    this.rearClearance = 20.0,
    this.lateralG = 0.0,
    this.tiltAngle = 0.0,
    this.ldwActive = false,
    this.lanePosition = 0.0,
    this.speed = 0.0,
    this.brakeActive = false,
    this.leftSignal = false,
    this.rightSignal = false,
    this.unitAOnline = true,
    this.unitBOnline = true,
    this.unitCOnline = true,
    this.unitDOnline = true,
  });
}
