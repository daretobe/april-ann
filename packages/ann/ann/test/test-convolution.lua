kx=17
ky=17
h=10
-- a matrix of ROWSxCOLUMNSx3
m = ImageIO.read(string.get_path(arg[0]) .. "photo.png"):matrix():transpose(1,3)
m2 = m:contiguous():rewrap(m:size())

input = matrix(2, m2:size())
input:select(1,1):copy(m2)
input:select(1,2):copy(m2)
thenet,w,_ = ann.components.stack():
-- converts a flatten image to a matrix of only 3 planes (RGB)
push(ann.components.rewrap{ size={ 3, m:dim()[2], m:dim()[3] } }):
-- a kernel over 3 planes and kx,ky sizes, h output neurons
push(ann.components.convolution{ kernel={3, kx, ky}, n=h }):
-- max pooling over every hidden neuron (planes) with 7x7 kernel
push(ann.components.max_pooling{ kernel={1,7,7} }):
push(ann.components.actf.hardtanh()):
-- a kernel over all hidden neurons (planes) and 5x5 sizes, h*2 output neurons
push(ann.components.convolution{ kernel={h,5,5}, n=h*2 }):
-- max pooling over every hidden neuron (planes) with 2x2 kernel
push(ann.components.max_pooling{ kernel={1,3,3} }):
push(ann.components.actf.hardtanh()):
build()
rnd=random(1234)
for name,cnn in pairs(w) do ann.connections.randomize_weights(cnn,{inf=-0.1,sup=0.1,random=rnd}) end
clock = util.stopwatch()
clock:go()
output = thenet:forward(input)

clock:stop()
print(m:size(), clock:read())
x = output:dim()[3]
y = output:dim()[4]
for b=1,output:dim()[1] do
  for i=1,output:dim()[2] do
    aux = output:select(1,b):select(1,i):clone()
    aux = aux:rewrap(x,y):adjust_range(0,1)
    ImageIO.write(Image(aux), "output-" .. b .. "-" .. i .. ".png")
  end
end

-- ann.save(thenet, "ww.net")
