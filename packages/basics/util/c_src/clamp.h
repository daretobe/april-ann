/*
 * This file is part of the Neural Network modules of the APRIL toolkit (A
 * Pattern Recognizer In Lua).
 *
 * Copyright 2012, Salvador España-Boquera, Jorge Gorbe Moya, Francisco Zamora-Martinez
 *
 * The APRIL-ANN toolkit is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this library; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 *
 */
#ifndef CLAMP_H
#define CLAMP_H

namespace april_utils {
  template <typename T>
  T clamp(T val, T lower, T upper)
  {
    if (val > upper) return upper;
    if (val < lower) return lower;
    return val;
  }
  
  template <typename T>
  T avoid_number(T val, T number, T epsilon)
  {
    if (((number - epsilon) < val) && (val < (number + epsilon))) {
      if (val < number) return number - epsilon ;
      else return number + epsilon;
    }
    return val;
  }
}

#endif // defined(CLAMP_H)