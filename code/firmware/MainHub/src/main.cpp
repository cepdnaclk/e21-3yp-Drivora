#include "../include/LaneDetector.hpp"
#include <iostream>
#include <opencv2/opencv.hpp>

int main() {
  cv::VideoCapture cap(0);

  if (!cap.isOpened()) {
    std::cerr << "CRITICAL ERROR: MainHub cannot connect to the camera payload."
              << std::endl;
    return -1;
  }

  std::cout << "MainHub Camera Online. Initializing LDWS Pipeline..."
            << std::endl;

  // Instantiate our custom class
  LaneDetector ld;
  cv::Mat rawFrame, processedFrame;

  while (true) {
    cap >> rawFrame;
    if (rawFrame.empty())
      break;

    // Pass the raw frame to our detector, get the fully processed frame back
    processedFrame = ld.processFrame(rawFrame);

    cv::imshow("ADAS Output", processedFrame);

    if (cv::waitKey(1) == 'q')
      break;
  }

  cap.release();
  cv::destroyAllWindows();
  return 0;
}