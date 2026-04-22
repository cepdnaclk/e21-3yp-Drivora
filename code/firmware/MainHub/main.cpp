#include <iostream>
#include <opencv2/opencv.hpp>

int main() {
  // Phase 1: Camera Ingestion
  // '0' opens the default camera (CSI or first USB webcam)
  cv::VideoCapture cap(0);

  if (!cap.isOpened()) {
    std::cerr << "CRITICAL ERROR: MainHub cannot connect to the camera payload."
              << std::endl;
    return -1;
  }

  std::cout << "MainHub Camera Online. Initializing LDWS Pipeline..."
            << std::endl;
  std::cout << "Press 'q' in any video window to terminate." << std::endl;

  // Matrices to hold our different image states
  cv::Mat rawFrame, grayFrame, blurFrame;

  // The main processing loop (runs every frame)
  while (true) {
    // Read the newest frame from the camera
    cap >> rawFrame;

    if (rawFrame.empty()) {
      std::cerr << "WARNING: Dropped frame." << std::endl;
      break;
    }

    // Phase 2: Frame Preprocessing
    // 1. Convert to Grayscale (Color is irrelevant for structural lines)
    cv::cvtColor(rawFrame, grayFrame, cv::COLOR_BGR2GRAY);

    // 2. Apply Gaussian Blur
    // A 5x5 kernel size is standard for removing asphalt noise while keeping
    // lane edges sharp
    cv::GaussianBlur(grayFrame, blurFrame, cv::Size(5, 5), 0);

    // Display the results on the Pi's connected monitor
    cv::imshow("1. Raw Camera Feed", rawFrame);
    cv::imshow("2. Preprocessed (Gray + Blur)", blurFrame);

    // Wait 1ms for the 'q' key to be pressed to exit the loop
    if (cv::waitKey(1) == 'q') {
      std::cout << "Termination signal received. Shutting down." << std::endl;
      break;
    }
  }

  // Clean up hardware resources
  cap.release();
  cv::destroyAllWindows();
  return 0;
}