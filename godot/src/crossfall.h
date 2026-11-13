#pragma once
#include <algorithm>
#include <cmath>
// Positive crossfall lowers the surface away from the centre. Signed distance
// is positive to the right in local east/south coordinates, looking forward.
inline double crossfall_drop(double distance,double signed_distance,double width,double left,double right) {
 return std::min(distance,width/2)*(signed_distance<0?left:right)/100.0;
}
