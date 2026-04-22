#include "../include/LaneDetector.hpp"

// Constructor (We can initialize dynamic variables here later)
LaneDetector::LaneDetector() {}

cv::Mat LaneDetector::preprocess(const cv::Mat& inputFrame) {
    cv::Mat gray, blur;
    cv::cvtColor(inputFrame, gray, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(gray, blur, cv::Size(5, 5), 0);
    return blur;
}

cv::Mat LaneDetector::regionOfInterest(const cv::Mat& img) {
    cv::Mat mask = cv::Mat::zeros(img.size(), img.type());
    int height = img.rows;
    int width = img.cols;
    
    cv::Point pts[4] = {
        cv::Point(0, height), 
        cv::Point(width / 2 - 50, height / 2 + 50), 
        cv::Point(width / 2 + 50, height / 2 + 50), 
        cv::Point(width, height)
    };
    
    cv::fillConvexPoly(mask, pts, 4, cv::Scalar(255));
    
    cv::Mat maskedImage;
    cv::bitwise_and(img, mask, maskedImage);
    return maskedImage;
}

std::vector<cv::Vec4i> LaneDetector::extractLines(const cv::Mat& roiFrame) {
    std::vector<cv::Vec4i> lines;
    cv::HoughLinesP(roiFrame, lines, 1, CV_PI/180, 50, 50, 10);
    return lines;
}

cv::Mat LaneDetector::processFrame(const cv::Mat& inputFrame) {
    // 1. Preprocess
    cv::Mat blurFrame = preprocess(inputFrame);
    
    // 2. Edge Detection
    cv::Mat cannyFrame;
    cv::Canny(blurFrame, cannyFrame, cannyLowThreshold, cannyHighThreshold);
    
    // 3. Apply Mask
    cv::Mat roiFrame = regionOfInterest(cannyFrame);
    
    // 4. Extract Lines
    std::vector<cv::Vec4i> lines = extractLines(roiFrame);
    
    // 5. Draw Lines on a blank canvas
    cv::Mat lineFrame = cv::Mat::zeros(inputFrame.size(), inputFrame.type());
    for(size_t i = 0; i < lines.size(); i++) {
        cv::Vec4i l = lines[i];
        cv::line(lineFrame, cv::Point(l[0], l[1]), cv::Point(l[2], l[3]), cv::Scalar(0, 0, 255), 3, cv::LINE_AA);
    }
    
    // 6. Overlay and return
    cv::Mat finalFrame;
    cv::addWeighted(inputFrame, 0.8, lineFrame, 1.0, 0.0, finalFrame);
    
    return finalFrame;
}