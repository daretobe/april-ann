#include "wrapper.h"
#include "token_memory_block.h"

TokenMemoryBlock::TokenMemoryBlock() : mem_block(0), used_size(0) { }

TokenMemoryBlock::TokenMemoryBlock(unsigned int size) : used_size(0) {
  mem_block = new GPUMirroredMemoryBlock(size);
}

TokenMemoryBlock::~TokenMemoryBlock() {
  delete mem_block;
}

void TokenMemoryBlock::resize(unsigned int size) {
  if (size > mem_block->getSize()) {
    delete mem_block;
    mem_block = new GPUMirroredMemoryBlock(size);
  }
  used_size = size;
}

Token *TokenMemoryBlock::clone() const {
  TokenMemoryBlock *token = new TokenMemoryBlock(mem_block->getSize());
  token->used_size = used_size;
  doScopy(mem_block->getSize(),
	  mem_block, 0, 1,
	  token->mem_block, 0, 1,
	  GlobalConf::use_cuda);
  return token;
}

buffer_list* TokenMemoryBlock::toString() {
  // NOT IMPLEMENTED
  return 0;
}

buffer_list* TokenMemoryBlock::debugString(const char *prefix, int debugLevel) {
  // NOT IMPLEMENTED
  return 0;
}

TokenCode TokenMemoryBlock::getTokenCode() const {
  return table_of_token_codes::token_mem_block;
}

static Token *TokenMemoryBlock::fromString(constString &cs) {
  // NOT IMPLEMENTED
  return 0;
}
