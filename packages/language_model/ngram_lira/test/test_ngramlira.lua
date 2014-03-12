local path = arg[0]:get_path()
local vocab = lexClass.load(io.open(path .. "vocab"))
local model = language_models.load(path .. "dihana3gram.lira.gz",
				  vocab, "<s>", "</s>")
local sum,numwords,numunks =
  ngram.get_sentence_prob(model, vocab,
 			  string.tokenize("quer'ia un tren con "..
					    "destino a barcelona"),
 			  io.stdout, 2,
 			    -1, vocab:getWordId("<s>"),
 			  vocab:getWordId("</s>"))

--print("TEST 2")
--
--model:prepare(key)
--prob,key = model:get(key, vocab:getWordId("quer'ia"))
--model:prepare(key)
--prob,key = model:get(key, vocab:getWordId("un"))
--model:prepare(key)
--prob,key = model:get(key, vocab:getWordId("billete"))
--printf("From %d ", key)
--model:prepare(key)
--prob,key = model:get(key, vocab:getWordId("a"))
--printf("To %d with %d = %f\n", key,
--       vocab:getWordId("a"), prob)
--
--key = model:findKeyFromNgram(vocab:searchWordIdSequence(string.tokenize("<s> quer'ia un billete")))
--model:prepare(key)
--printf("From %d ", key)
--prob,key = model:get(key, vocab:getWordId("a"))
--printf("To %d with %d = %f\n", key,
--       vocab:getWordId("a"), prob)
