#pragma once
#include <opencv2/opencv.hpp>
#include <vector>

class LaneDetector {
private:
  // Tunable thresholds for our algorithms
  int cannyLowThreshold = 50;
  int cannyHighThreshold = 150;

  // Internal helper functions
  cv::Mat preprocess(const cv::Mat &inputFrame);
  cv::Mat regionOfInterest(const cv::Mat &img);
  std::vector<cv::Vec4i> extractLines(const cv::Mat &roiFrame);

public:
  // Constructor
  LaneDetector();

  // The main public function that main.cpp will call
  cv::Mat processFrame(const cv::Mat &inputFrame);
};