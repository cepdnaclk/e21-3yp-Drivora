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
  // --- FRONT UNIT (FCW) ---
  final int frontState;
  final String frontStateName;
  final Color frontStateColor;
  final double frontDistance;
  final double closingSpeed;
  final bool frontOnline;

  // --- LEAN UNIT (COG) ---
  final int leanRiskLevel;
  final String leanRiskName;
  final double roll;
  final double pitch;
  final double confidence;
  final bool leanOnline;
  final bool leanCalibrated;
  final double criticalRollDeg;
  final double criticalPitchDeg;

  // --- REAR UNIT (BSM) ---
  final int rearState;
  final String rearStateName;
  final Color rearStateColor;
  final double rearDistance;
  final bool rearOnline;

  // --- VIRTUAL / DERIVED ---
  final bool ldwActive;
  final double lanePosition;
  
  // System Basics
  final double speed; 
  final bool brakeActive;
  
  // Legacy support for other screens
  bool get unitAOnline => frontOnline;
  bool get unitBOnline => rearOnline;
  bool get unitCOnline => leanOnline;
  bool get unitDOnline => true; // Lane virtual
  double get ttc => (closingSpeed > 0 && frontDistance > 0) ? (frontDistance / closingSpeed) : 10.0;
  double get tiltAngle => roll;
  double get lateralG => pitch;
  double get rearClearance => rearDistance;

  DrivoraSensorData({
    this.frontState = 0,
    this.frontStateName = "CLEAR",
    this.frontStateColor = const Color(0xFF1DB954),
    this.frontDistance = -1.0,
    this.closingSpeed = 0.0,
    this.frontOnline = false,
    this.leanRiskLevel = 0,
    this.leanRiskName = "SAFE",
    this.roll = 0.0,
    this.pitch = 0.0,
    this.confidence = 1.0,
    this.leanOnline = false,
    this.leanCalibrated = false,
    this.criticalRollDeg = 30.0,
    this.criticalPitchDeg = 20.0,
    this.rearState = 0,
    this.rearStateName = "CLEAR",
    this.rearStateColor = const Color(0xFF1DB954),
    this.rearDistance = -1.0,
    this.rearOnline = false,
    this.ldwActive = false,
    this.lanePosition = 0.0,
    this.speed = 0.0,
    this.brakeActive = false,
  });
}
