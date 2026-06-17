// Filtre de Madgwick (IMU : gyroscope + accéléromètre, sans magnétomètre)
// D'après S. Madgwick, "An efficient orientation filter for inertial and
// inertial/magnetic sensor arrays" (2010).
#pragma once
#include <math.h>

class Madgwick {
public:
  // quaternion : orientation du capteur par rapport au repère terrestre
  float q0 = 1, q1 = 0, q2 = 0, q3 = 0;

  // gx,gy,gz en rad/s — ax,ay,az en g (normalisés en interne)
  // beta : gain de correction par l'accéléromètre (haut = converge vite
  // mais sensible aux accélérations linéaires)
  void update(float gx, float gy, float gz,
              float ax, float ay, float az,
              float beta, float dt) {
    // dérivée du quaternion d'après le gyroscope
    float qDot0 = 0.5f * (-q1 * gx - q2 * gy - q3 * gz);
    float qDot1 = 0.5f * ( q0 * gx + q2 * gz - q3 * gy);
    float qDot2 = 0.5f * ( q0 * gy - q1 * gz + q3 * gx);
    float qDot3 = 0.5f * ( q0 * gz + q1 * gy - q2 * gx);

    float norm = sqrtf(ax * ax + ay * ay + az * az);
    if (norm > 1e-6f) {
      float inv = 1.0f / norm;
      ax *= inv; ay *= inv; az *= inv;

      // descente de gradient : aligne la gravité estimée sur la mesure
      float _2q0 = 2 * q0, _2q1 = 2 * q1, _2q2 = 2 * q2, _2q3 = 2 * q3;
      float _4q0 = 4 * q0, _4q1 = 4 * q1, _4q2 = 4 * q2;
      float _8q1 = 8 * q1, _8q2 = 8 * q2;
      float q0q0 = q0 * q0, q1q1 = q1 * q1, q2q2 = q2 * q2, q3q3 = q3 * q3;

      float s0 = _4q0 * q2q2 + _2q2 * ax + _4q0 * q1q1 - _2q1 * ay;
      float s1 = _4q1 * q3q3 - _2q3 * ax + 4 * q0q0 * q1 - _2q0 * ay
               - _4q1 + _8q1 * q1q1 + _8q1 * q2q2 + _4q1 * az;
      float s2 = 4 * q0q0 * q2 + _2q0 * ax + _4q2 * q3q3 - _2q3 * ay
               - _4q2 + _8q2 * q1q1 + _8q2 * q2q2 + _4q2 * az;
      float s3 = 4 * q1q1 * q3 - _2q1 * ax + 4 * q2q2 * q3 - _2q2 * ay;

      float sn = sqrtf(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3);
      if (sn > 1e-9f) {
        float si = 1.0f / sn;
        qDot0 -= beta * s0 * si;
        qDot1 -= beta * s1 * si;
        qDot2 -= beta * s2 * si;
        qDot3 -= beta * s3 * si;
      }
    }

    q0 += qDot0 * dt;
    q1 += qDot1 * dt;
    q2 += qDot2 * dt;
    q3 += qDot3 * dt;
    float qn = 1.0f / sqrtf(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3);
    q0 *= qn; q1 *= qn; q2 *= qn; q3 *= qn;
  }

  // Composante verticale (axe terrestre "haut") d'un vecteur exprimé
  // dans le repère capteur. Pour l'accéléromètre au repos : renvoie ~1 g.
  float verticalOf(float ax, float ay, float az) const {
    float vx = 2 * (q1 * q3 - q0 * q2);
    float vy = 2 * (q0 * q1 + q2 * q3);
    float vz = q0 * q0 - q1 * q1 - q2 * q2 + q3 * q3;
    return ax * vx + ay * vy + az * vz;
  }
};
