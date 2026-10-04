#pragma once

// sturct til oplæring af 3d vektore
struct vec3d {
  double x = 0;
  double y = 0;
  double z = 0;

  // plus af to vektore
  vec3d &operator+=(const vec3d &other) {
    x += other.x;
    y += other.y;
    z += other.z;

    return *this;
  }

  vec3d operator+(const vec3d &other) const {
    return vec3d{this->x + other.x, this->y + other.y, this->z + other.z};
  }

  // minus af to vektore
  vec3d &operator-=(const vec3d &other) {
    x -= other.x;
    y -= other.y;
    z -= other.z;

    return *this;
  }

  vec3d operator-(const vec3d &other) const {
    return vec3d{this->x - other.x, this->y - other.y, this->z - other.z};
  }

  vec3d operator*(const vec3d &other) const {
    return vec3d{this->x * other.x, this->y * other.y, this->z * other.z};
  }

  // skalar ganget med en vektore
  vec3d operator*(double other) const {
    return vec3d{this->x * other, this->y * other, this->z * other};
  }
};

inline double dot(vec3d a, vec3d b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

inline vec3d cross(vec3d a, vec3d b) {
  return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x};
}

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
