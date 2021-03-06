/*
 * This file is part of APRIL-ANN toolkit (A
 * Pattern Recognizer In Lua with Artificial Neural Networks).
 *
 * Copyright 2014, Francisco Zamora-Martinez
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
#ifndef APRIL_PRINT_H
#define APRIL_PRINT_H
#include <cstdio>

namespace AprilUtils {
  void aprilPrint(const float &v);
  void aprilPrint(const double &v);
  void aprilPrint(const char &v);
  void aprilPrint(const int &v);
  void aprilPrint(const unsigned int &v);
  void aprilPrint(const bool &v);
  template<typename T>
  void aprilPrint(const char *str1, const T &v, const char *str2) {
    if (str1 != 0) printf("%s",str1);
    aprilPrint(v);
    if (str2 != 0) printf("%s",str2);
  }
}
#endif // APRIL_PRINT_H
