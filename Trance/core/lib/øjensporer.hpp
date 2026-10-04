#include "Trance-Swift.h"
#include <cmath>
#include <vector>

// sturct til oplæring af 3d vektore
struct vec3d {
  double x;
  double y;
  double z;

  // plus af to vektore
  vec3d operator+=(const vec3d &other) {
    return vec3d{this->x += other.x, this->y += other.y, this->z += other.z};
  }

  vec3d operator+(const vec3d &other) const {
    return vec3d{this->x + other.x, this->y + other.y, this->z + other.z};
  }

  // minus af to vektore
  vec3d operator-=(const vec3d &other) {
    return vec3d{this->x -= other.x, this->y -= other.y, this->z -= other.z};
  }

  vec3d operator-(const vec3d &other) const {
    return vec3d{this->x - other.x, this->y - other.y, this->z - other.z};
  }

  // dot produktet af to vektore
  vec3d operator*(const vec3d &other) const {
    return vec3d{this->x * other.x, this->y * other.y, this->z * other.z};
  }

  // skalar ganget med en vektore
  vec3d operator*(const float &other) const {
    return vec3d{this->x * other, this->y * other, this->z * other};
  }
};

struct plane {
  vec3d normalVector;
  vec3d point;
};

class øjensporer {
public:
  øjensporer();
  ~øjensporer();

  void fokuspoint();
  void ScreenPlane();

private:
  plane m_screenPlane;
};
