/*
 * This file is part of APRIL-ANN toolkit (A
 * Pattern Recognizer In Lua with Artificial Neural Networks).
 *
 * Copyright 2013, Salvador España-Boquera, Francisco Zamora-Martinez
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
#ifndef TOKEN_VECTOR_H
#define TOKEN_VECTOR_H

#include "pair.h"
#include "token_base.h"
#include "vector.h"

namespace basics {

  class TokenVectorGeneric : public Token {
    APRIL_DISALLOW_COPY_AND_ASSIGN(TokenVectorGeneric);
  public:
    TokenVectorGeneric() : Token() { }
    virtual unsigned int size() const = 0;
    virtual void clear() = 0;
  };

  template <typename T>
  class TokenVector : public TokenVectorGeneric {
    APRIL_DISALLOW_COPY_AND_ASSIGN(TokenVector);
    april_utils::vector<T> vec;
  public:
    TokenVector();
    TokenVector(unsigned int vlength);
    // always copy the vector
    TokenVector(const T *vec, unsigned int vlength);
    TokenVector(const april_utils::vector<T> &vec);
    ~TokenVector();
  
    T& operator[] (unsigned int i) { return vec[i]; }
    const T& operator[] (unsigned int i) const { return vec[i]; }
    april_utils::vector<T> &getContainer() { return vec; }
    const april_utils::vector<T> &getContainer() const { return vec; }
    void push_back(T const &data) { vec.push_back(data); }
    T *data() { return vec.begin(); }
    const T *data() const { return vec.begin(); }
    Token *clone() const;
    april_utils::buffer_list* toString();
    april_utils::buffer_list* debugString(const char *prefix, int debugLevel);
    TokenCode getTokenCode() const;
    static Token *fromString(april_utils::constString &cs);
    virtual unsigned int size() const { return vec.size(); }
    virtual void clear() { vec.clear(); }
  };

  typedef TokenVector<float>    TokenVectorFloat;
  typedef TokenVector<double>   TokenVectorDouble;
  typedef TokenVector<int32_t>  TokenVectorInt32;
  typedef TokenVector<uint32_t> TokenVectorUint32;
  typedef TokenVector<char>     TokenVectorChar;
  typedef TokenVector<Token*>   TokenBunchVector;

  /* forward declarations */

  template<>
  april_utils::buffer_list* TokenVector<float>::toString();

  template<>
  april_utils::buffer_list* TokenVector<float>::debugString(const char *prefix,
                                                            int debugLevel);

  template <>
  TokenCode TokenVector<float>::getTokenCode() const;

  template <>
  Token *TokenVector<float>::fromString(april_utils::constString &cs);

  // ------------------------- vector double -------------------------

  template <>
  april_utils::buffer_list* TokenVector<double>::toString();
  
  template <>
  april_utils::buffer_list* TokenVector<double>::debugString(const char *prefix,
                                                             int debugLevel);

  template <>
  TokenCode TokenVector<double>::getTokenCode() const;

  template <>
  Token *TokenVector<double>::fromString(april_utils::constString &cs);

  // ------------------------- vector int32 -------------------------

  template <>
  april_utils::buffer_list* TokenVector<int32_t>::toString();

  template <>
  april_utils::buffer_list* TokenVector<int32_t>::debugString(const char *prefix,
                                                              int debugLevel);

  template <>
  TokenCode TokenVector<int32_t>::getTokenCode() const;

  template <>
  Token *TokenVector<int32_t>::fromString(april_utils::constString &cs);

  // ------------------------- vector uint32_t -------------------------

  template <>
  april_utils::buffer_list* TokenVector<uint32_t>::toString();

  template <>
  april_utils::buffer_list* TokenVector<uint32_t>::debugString(const char *prefix,
                                                               int debugLevel);

  template <>
  TokenCode TokenVector<uint32_t>::getTokenCode() const;

  template <>
  Token *TokenVector<uint32_t>::fromString(april_utils::constString &cs);

  // ------------------------- vector char -------------------------

  template <>
  april_utils::buffer_list* TokenVector<char>::toString();

  template <>
  april_utils::buffer_list* TokenVector<char>::debugString(const char *prefix,
                                                           int debugLevel);

  template <>
  TokenCode TokenVector<char>::getTokenCode() const;

  template <>
  Token *TokenVector<char>::fromString(april_utils::constString &cs);


  // ------------------------- vector token -------------------------

  template <>
  TokenVector<Token*>::TokenVector(Token * const *vec, unsigned int vlength);

  template <>
  TokenVector<Token*>::TokenVector(const april_utils::vector<Token*> &vec);

  template<>
  void TokenVector<Token*>::clear();

  template<>
  void TokenVector<Token*>::push_back(Token* const &data);

  template <>
  TokenVector<Token*>::~TokenVector();

  template <>
  april_utils::buffer_list* TokenVector<Token*>::toString();

  template <>
  april_utils::buffer_list* TokenVector<Token*>::debugString(const char *prefix,
                                                             int debugLevel);

  template <>
  TokenCode TokenVector<Token*>::getTokenCode() const;

  template <>
  Token *TokenVector<Token*>::fromString(april_utils::constString &cs);

} // namespace basics

#endif // TOKEN_VECTOR_H
