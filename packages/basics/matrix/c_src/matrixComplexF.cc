/*
 * This file is part of APRIL-ANN toolkit (A
 * Pattern Recognizer In Lua with Artificial Neural Networks).
 *
 * Copyright 2013, Francisco Zamora-Martinez
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

#include "swap.h"
#include "matrix.h"
#include "matrixComplexF.h"
#include "matrix_generic_math_templates.h" // functions which apply functors
#include "matrix_generic_math_functors.h"  // standard functors
#include "wrapper.h" // wrappers of mathematical function (for CPU/GPU)

// WARNING: ALL THE METHODS IMPLEMENTED HERE ARE SPECIALIZED TO COMPLEXF VERSION

namespace basics {
  typedef april_math::ComplexF ComplexF;
  
  /************* FILL FUNCTION **************/
  DEF_CWISE_FUNCTOR_1(doFill,ComplexF);
  template<>
  void Matrix<ComplexF>::fill(ComplexF value) {
    applyFunctionWithSpanIterator<ComplexF>(this,
                                            MAKE_CWISE_FUNCTOR_1(doFill,ComplexF,
                                                                 value));
  }

  // COMPONENT-WISE MULTIPLICATION
  struct cmul_functor {
    cmul_functor() { }
    void operator()(MatrixComplexF *one, const MatrixComplexF *other,
                    unsigned int size,
                    unsigned int stride_one,
                    unsigned int stride_other,
                    unsigned int offset_one,
                    unsigned int offset_other) const {
      doCmul(size,
             other->getRawDataAccess(),
             offset_other, stride_other,
             one->getRawDataAccess(),
             offset_one, stride_one,
             one->getCudaFlag());
    }
  };
  template<>
  void Matrix<ComplexF>::cmul(const Matrix<ComplexF> *other) {
    if (size() != other->size())
      ERROR_EXIT2(128, "Incorrect matrices sizes: %d != %d\n",
                  size(), other->size());
    if (major_order != other->major_order)
      ERROR_EXIT(128, "Matrices with different major orders\n");
    cmul_functor functor;
    applyBinaryFunctionWithSpanIterator<ComplexF>(this, other, functor);
  }

  /************* SUM FUNCTION **************/
  struct sum_functor {
    ComplexF operator()(const MatrixComplexF *m,
                        unsigned int size, unsigned int stride,
                        unsigned int offset) const {
      return doSum(size, m->getRawDataAccess(), stride, offset,
                   m->getCudaFlag(), ComplexF::zero_zero());
    }
  };
  template<>
  ComplexF Matrix<ComplexF>::sum() const {
    sum_functor functor;
    return applySumReductionWithSpanIteratorNOPARALLEL<ComplexF>(this, functor);
  }

  /**** COMPONENT WISE OPERATIONS ****/


  /************* scalarAdd FUNCTION **************/
  DEF_CWISE_FUNCTOR_1(doScalarAdd,ComplexF);
  template<>
  void Matrix<ComplexF>::scalarAdd(ComplexF s) {
    applyFunctionWithSpanIterator<ComplexF>(this,
                                            MAKE_CWISE_FUNCTOR_1(doScalarAdd,
                                                                 ComplexF,s));
  }

  /************* equals FUNCTION **************/
  struct equals_functor {
    float epsilon;
    equals_functor(float epsilon) : epsilon(epsilon) { }
    bool operator()(const MatrixComplexF *m1,
                    const MatrixComplexF *m2,
                    unsigned int size,
                    unsigned int stride1,
                    unsigned int stride2,
                    unsigned int offset1,
                    unsigned int offset2) const {
      return doEquals(size, m1->getRawDataAccess(), m2->getRawDataAccess(),
                      stride1, stride2, offset1, offset2, epsilon,
                      m1->getCudaFlag() && m2->getCudaFlag());
    }
  };
  template<>
  bool Matrix<ComplexF>::equals(const Matrix<ComplexF> *other,
                                float epsilon) const {
    if (!sameDim(other)) return false;
    equals_functor functor(epsilon);
    return applyBinaryAndReductionWithSpanIterator<ComplexF>(this,other,functor);
  }

  /**** BLAS OPERATIONS ****/
  struct copy_functor {
    void operator()(MatrixComplexF *dest, const MatrixComplexF *orig,
                    unsigned int size,
                    unsigned int stride_dest,
                    unsigned int stride_orig,
                    unsigned int offset_dest,
                    unsigned int offset_orig) const {
      doCopy(size,
             orig->getRawDataAccess(),
             offset_orig, stride_orig,
             dest->getRawDataAccess(),
             offset_dest, stride_dest,
             orig->getCudaFlag());
    }
  };
  template<>
  void Matrix<ComplexF>::copy(const Matrix<ComplexF> *other) {
    if (this != other) {
      if (size() != other->size())
        ERROR_EXIT2(128, "Incorrect matrices sizes: %d != %d\n",
                    size(), other->size());
      if (major_order != other->major_order)
        ERROR_EXIT(128, "Matrices with different major orders\n");
      if (! sameDim(other) )
        ERROR_EXIT(128, "Matrices with different dimension sizes\n");
      use_cuda = other->use_cuda;
      copy_functor functor;
      applyBinaryFunctionWithSpanIterator<ComplexF>(this, other, functor);
    }
  }

  /********** SCAL FUNCTION ***************/
  DEF_CWISE_FUNCTOR_1(doScal,ComplexF);
  template<>
  void Matrix<ComplexF>::scal(ComplexF value) {
#ifdef USE_MKL
    applyFunctionWithSpanIteratorNOPARALLEL<ComplexF>(this,
                                                      MAKE_CWISE_FUNCTOR_1(doScal,
                                                                           ComplexF,
                                                                           value));
#else
    applyFunctionWithSpanIterator<ComplexF>(this,
                                            MAKE_CWISE_FUNCTOR_1(doScal,ComplexF,
                                                                 value));
#endif
  }

  /********** NORM2 FUNCTION ***************/
  struct norm2_functor {
    float operator()(const MatrixComplexF *m, unsigned int size, unsigned int stride,
                     unsigned int offset) const {
      return doNrm2(size, m->getRawDataAccess(), stride, offset,
                    m->getCudaFlag());
    }
  };
  struct norm2_reductor {
    float operator()(float accum, float other) const {
      return accum + other*other;
    }
  };
  // In this method we do ad-hoc specialization of BASIC cases because
  // we avoid the SQUARE and SQRT functions
  template<>
  float Matrix<ComplexF>::norm2() const {
    float v;
    // Contiguous memory block
    if (getIsContiguous()) {
      v=doNrm2(total_size, data.get(), 1, offset, use_cuda);
    }
    // One dimension
    else if (numDim == 1) {
      v=doNrm2(total_size, data.get(), stride[0], offset, use_cuda);
    }
    // General case
    else {
      norm2_functor  functor;
      norm2_reductor reductor;
      v = applyReductionWithSpanIteratorNOPARALLEL<ComplexF,float>(this,
                                                                   functor,
                                                                   reductor,
                                                                   0.0f);
      v = sqrtf(v);
    }
    return v;
  }

  template class Matrix<ComplexF>;

} // namespace basics
