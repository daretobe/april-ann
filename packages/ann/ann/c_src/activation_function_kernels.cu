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
#include "activation_function_kernels.h"
#include "april_assert.h"
#include "cblas_headers.h"
#include "cmath_overloads.h"
#include "map_matrix.h"
#include "reduce_matrix.h"
#include "smart_ptr.h"

using namespace AprilMath;
using namespace AprilMath::MatrixExt;
using namespace AprilMath::MatrixExt::Operations;

namespace ANN {
  namespace Kernels {
    
    void applyHardTanhDerivative(Basics::MatrixFloat *output_errors,
                                 Basics::MatrixFloat *input_units,
                                 float inf, float sup) {
      MatrixScalarMap1(input_units,
                       AprilMath::m_curried_clamp_der<float>(inf, sup),
                       output_errors);
    }

    void applyTanh(Basics::MatrixFloat *output,
                   Basics::MatrixFloat *input) {
      MatrixScalarMap1(input,
                       AprilMath::Functors::m_antisym_logistic<float>(),
                       output);
    }
    
    void applyTanhDerivative(Basics::MatrixFloat *output_errors,
                             Basics::MatrixFloat *output_units) {
      MatrixScalarMap1(output_units,
                       AprilMath::Functors::m_antisym_logistic_der<float>(),
                       output_errors);
    }

    
    void applyLogistic(Basics::MatrixFloat *output,
                       Basics::MatrixFloat *input) {
      MatrixScalarMap1(input,
                       AprilMath::Functors::m_logistic<float>(),
                       output);
    }
    
    void applyLogisticDerivative(Basics::MatrixFloat *output_errors,
                                 Basics::MatrixFloat *output_units) {
      MatrixScalarMap1(output_units,
                       AprilMath::Functors::m_logistic_der<float>(),
                       output_errors);
    }
    
    void applySoftsign(Basics::MatrixFloat *output,
                       Basics::MatrixFloat *input) {
      MatrixScalarMap1(input,
                       AprilMath::Functors::m_softsign<float>(),
                       output);
    }
    
    void applySoftsignDerivative(Basics::MatrixFloat *output_errors,
                                 Basics::MatrixFloat *output_units) {
      MatrixScalarMap1(output_units,
                       AprilMath::Functors::m_softsign_der<float>(),
                       output_errors);
    }

    void applySoftplus(Basics::MatrixFloat *output,
                       Basics::MatrixFloat *input) {
      MatrixScalarMap1(input,
                       AprilMath::Functors::m_softplus<float>(),
                       output);
    }
    
    void applySoftplusDerivative(Basics::MatrixFloat *output_errors,
                                 Basics::MatrixFloat *input_units) {
      MatrixScalarMap1(input_units,
                       AprilMath::Functors::m_softplus_der<float>(),
                       output_errors);
    }

    void applyReLU(Basics::MatrixFloat *output,
                   Basics::MatrixFloat *input) {
      MatrixScalarMap1(input,
                       AprilMath::Functors::m_relu<float>(),
                       output);
    }
    
    void applyReLUDerivative(Basics::MatrixFloat *output_errors,
                             Basics::MatrixFloat *input_units) {
      MatrixScalarMap1(input_units,
                       AprilMath::Functors::m_relu_der<float>(),
                       output_errors);
    }

    void applyLogLogistic(Basics::MatrixFloat *output,
                          Basics::MatrixFloat *input) {
      MatrixScalarMap1(input,
                       AprilMath::Functors::m_log_logistic<float>(),
                       output);
    }

    void applySoftmax(Basics::MatrixFloat *output,
                      Basics::MatrixFloat *input) {
      unsigned int bunch_size = input->getDimSize(0);
      unsigned int size = input->getDimSize(1);
#ifdef USE_CUDA
      if (input->getCudaFlag()) {
        AprilUtils::SharedPtr<Basics::MatrixFloat> maximums( matMax(input,1) );
        matCopy(output, input);
        AprilUtils::SharedPtr<Basics::MatrixFloat> column;
        for (unsigned int i=0; i<size; ++i) {
          column = output->select(1,i,column.get());
          matAxpy(column.get(), -1.0f, maximums.get());
        }
        maximums.reset(); // frees the memory
        matExp(output);
        AprilUtils::SharedPtr<Basics::MatrixFloat> sums( matSum(output,1) );
        // Avoid overhead of division operator inside loop.
        matDiv(sums.get(), 1.0f); // divide once
        for (unsigned int i=0; i<size; ++i) {
          column = output->select(1,i,column.get());
          matCmul(column.get(), sums.get()); // multiply several times
        }
      }
      else {
#endif
        AprilMath::FloatGPUMirroredMemoryBlock *input_units =
          input->getRawDataAccess();
        AprilMath::FloatGPUMirroredMemoryBlock *output_units =
          output->getRawDataAccess();
        const float *input_units_ptr = input_units->getPPALForRead();
        float *output_units_ptr      = output_units->getPPALForWrite();

        for (unsigned int b = 0; b < bunch_size; ++b) {
          float minimum = input_units_ptr[0];
          float maximum = input_units_ptr[0];
          unsigned int cur_pos = bunch_size;
          for (unsigned int i = 2; i < size; i += 2) {
            float prev_unit = input_units_ptr[cur_pos];
            cur_pos += bunch_size;
            float cur_unit = input_units_ptr[cur_pos];
            cur_pos += bunch_size;
            if (prev_unit < cur_unit) {
              if (prev_unit < minimum) minimum = prev_unit;
              if (cur_unit > maximum) maximum = cur_unit;
            } else {
              if (cur_unit < minimum) minimum = cur_unit;
              if (prev_unit > maximum) maximum = prev_unit;
            }
          }
          if ((size & 1) == 0) { // si es impar
            unsigned int last_pos = (size - 1) * bunch_size;
            if (input_units_ptr[last_pos] < minimum)
              minimum = input_units_ptr[last_pos];
            if (input_units_ptr[last_pos] > maximum)
              maximum = input_units_ptr[last_pos];
          }
          if ((maximum - minimum) > 30.0f) minimum = maximum - 30.0f;
          double addition = 0;
          cur_pos = 0;
          for (unsigned int i = 0; i < size; i++) {
            double e = exp(input_units_ptr[cur_pos] - minimum);
            output_units_ptr[cur_pos] = e;
            addition += e;
            cur_pos  += bunch_size;
          }
          float ratio = 1.0f/addition;
          cblas_sscal(size, ratio, output_units_ptr, bunch_size);
          output_units_ptr++;
          input_units_ptr++;
        }
#ifdef USE_CUDA
      }
#endif
    }
    
    void applyLogSoftmax(Basics::MatrixFloat *output,
                         Basics::MatrixFloat *input) {
      unsigned int bunch_size = input->getDimSize(0);
      unsigned int size = input->getDimSize(1);
#ifdef USE_CUDA
      if (input->getCudaFlag()) {
        AprilUtils::SharedPtr<Basics::MatrixFloat> maximums( matMax(input,1) );
        matCopy(output, input);
        AprilUtils::SharedPtr<Basics::MatrixFloat> column;
        for (unsigned int i=0; i<size; ++i) {
          column = output->select(1,i,column.get());
          matAxpy(column.get(), -1.0f, maximums.get());
        }
        maximums.reset();
        AprilUtils::SharedPtr<Basics::MatrixFloat> sums;
        sums = MatrixScalarReduce1OverDimension
          (output, // b
           1,      // dimension for the reduction
         // This template instantiates an operator like this:
         // operator()(acc, b) { acc += exp(b); }
           AprilMath::
           make_r_map1<float,float>(// aux = exp(b)
                                    AprilMath::Functors::m_exp<float>(),
                                    // acc += aux
                                    AprilMath::Functors::r_add<float,float>() ),
           AprilMath::Functors::r_add<float,float>(),
           0.0f);
        matLog(sums.get());
        for (unsigned int i=0; i<size; ++i) {
          column = output->select(1,i,column.get());
          matAxpy(column.get(), -1.0f, sums.get());
        }
      }
      else {
#endif
        AprilMath::FloatGPUMirroredMemoryBlock *input_units =
          input->getRawDataAccess();
        AprilMath::FloatGPUMirroredMemoryBlock *output_units =
          output->getRawDataAccess();
        const float *input_units_ptr = input_units->getPPALForRead();
        float *output_units_ptr      = output_units->getPPALForWrite();

        for (unsigned int b = 0; b < bunch_size; ++b) {
          float maximum = input_units_ptr[0];
          unsigned int cur_pos = bunch_size;
          for (unsigned int i = 2; i < size; i += 2) {
            float prev_unit = input_units_ptr[cur_pos];
            cur_pos += bunch_size;
            float cur_unit = input_units_ptr[cur_pos];
            if (prev_unit < cur_unit) {
              if (cur_unit > maximum) maximum = cur_unit;
            } else {
              if (prev_unit > maximum) maximum = prev_unit;
            }
            cur_pos += bunch_size;
          }
          if ((size & 1) == 0) { // si es par
            unsigned int last_pos = (size - 1) * bunch_size;
            if (input_units_ptr[last_pos] > maximum)
              maximum = input_units_ptr[last_pos];
          }
          double addition = 0.0f;
          cur_pos = 0;
          for (unsigned int i = 0; i < size; i++) {
            output_units_ptr[cur_pos] = input_units_ptr[cur_pos] - maximum;
            double exp_output = AprilMath::m_exp(static_cast<double>(output_units_ptr[cur_pos]));
            addition += exp_output;
            cur_pos  += bunch_size;
          }
          float ratio = static_cast<float>(log(addition));
          cur_pos = 0;
          for (unsigned int i = 0; i < size; i++) {
            output_units_ptr[cur_pos] -= ratio;
            april_assert(!(output_units_ptr[cur_pos] > 0.0f) &&
                         "Numerical inestability at log-softmax activation function");
            cur_pos += bunch_size;
          }
          output_units_ptr++;
          input_units_ptr++;
        }
#ifdef USE_CUDA
      }
#endif      
    }
    
    void applySoftmaxDerivative(Basics::MatrixFloat *output_errors_mat,
                                Basics::MatrixFloat *input_errors_mat,
                                Basics::MatrixFloat *output_units_mat) {
      unsigned int size = output_units_mat->getDimSize(1);
      AprilUtils::SharedPtr<Basics::MatrixFloat> column, sums;
      sums = MatrixScalarReduce2OverDimension
        (output_units_mat, // b
         input_errors_mat, // c
         1,                // dimension for the reduction
         // This template instantiates an operator like this:
         // operator()(acc, b, c) { acc += b * c; }
         AprilMath::
         make_r_map2<float,float,float>(// aux = b*c
                                        AprilMath::Functors::m_mul<float>(),
                                        // acc += aux
                                        AprilMath::Functors::r_add<float,float>() ),
         AprilMath::Functors::r_add<float,float>(),
         0.0f);
      matCopy(output_errors_mat, input_errors_mat);
      for (unsigned int i=0; i<size; ++i) {
        column = output_errors_mat->select(1,i,column.get());
        matAxpy(column.get(), -1.0f, sums.get());
      }
      matCmul(output_errors_mat, output_units_mat);
    }
  } // namespace Kernels
} // namespace ANN