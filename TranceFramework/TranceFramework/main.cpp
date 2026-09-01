#include "iostream"

struct eyePos{
  int x;
  int y;
};

int main () {
  int pulseÆndring = 0;
  int HRV = 0;
  float eda = 0;
  float headStability = 0;
  float gazeStability = 0;
  int blinkRate = 0;
  
  std::cout << "pulse ændring";
  std::cin >> pulseÆndring;
  std::cout << "Heart rate variability";
  std::cin >> HRV;
  std::cout <<"Electrodermal activity";
  std::cin >> eda;
  std::cout << "head stability";
  std::cin >> headStability;
  std::cout << "gaze stability";
  std::cin >> gazeStability;
  std::cout << "blink rate";
  std::cin >> blinkRate;


  if(pulseÆndring <= -5 & HRV <= 25 & eda <= 10e6 & headStability <= 80 & gazeStability <= 70 & blinkRate <= 21){
    std::cout << "afslappet";
  } else {
    std::cout << "ikke afslappet";
  }
  return 0;
}
