---
layout:     post
title:      "Accelerating your C++ on GPU with SYCL"
category:   c++
tags:
 - c++
 - gpgpu
---

Leveraging the power of graphics cards for compute applications is all the rage right now in fields such as neural networks, scientific programming, high-performance computing, and more. Technologies like OpenCL expose this power through a hardware-independent programming model, allowing you to write code which abstracts over different architecture capabilities. The dream of this is "write once, run anywhere", be it an Intel CPU, AMD discrete GPU, DSP, etc. Unfortunately for everyday programmers, OpenCL has something of a steep learning curve; a simple Hello World program can be a hundred or so lines of pretty ugly-looking code. Fortunately, the Khronos group have developed a new standard called [SYCL](https://www.khronos.org/sycl), which is a C++ abstraction layer on top of OpenCL. Using SYCL, you can develop these general-purpose GPU (GPGPU) applications in clean, modern C++ without most of the faff associated with OpenCL. Here's a simple vector multiplication example written in SYCL:

{% highlight cpp %}
#include <vector>
#include <iostream>

#include <sycl/execution_policy>
#include <experimental/algorithm>
#include <sycl/helpers/sycl_buffers.hpp>

using namespace std::experimental::parallel;
using namespace sycl::helpers;

int main() {
  std::vector<int> v = {3, 1, 5, 6};

  {
    cl::sycl::buffer<int> b(v.data(), cl::sycl::range<1>(v.size()));
    cl::sycl::default_selector h;
    cl::sycl::queue q(h);
    sycl::sycl_execution_policy<class Mul> sycl_policy(q);
    transform(sycl_policy, begin(b), end(b), begin(b),
              [](int x) { return x*2; });
  }

  for (size_t i = 0; i < v.size(); i++) {
    std::cout << v[i] << " ";
  }
}
{% endhighlight %}

For comparison, here's a mostly equivalent version written in OpenCL using the C++ API (don't spend much time reading this, just note that it looks ugly and is really long):

{% highlight cpp %}
#include <iostream>
#include <CL/cl.hpp>

int main(){
    std::vector<cl::Platform> all_platforms;
    cl::Platform::get(&all_platforms);
    if(all_platforms.size()==0){
        std::cout<<" No platforms found. Check OpenCL installation!\n";
        exit(1);
    }
    cl::Platform default_platform=all_platforms[0];

    std::vector<cl::Device> all_devices;
    default_platform.getDevices(CL_DEVICE_TYPE_ALL, &all_devices);
    if(all_devices.size()==0){
        std::cout<<" No devices found. Check OpenCL installation!\n";
        exit(1);
    }

    cl::Device default_device=all_devices[0];
    cl::Context context({default_device});

    cl::Program::Sources sources;
    std::string kernel_code=
                    "   void kernel mul2(global int* A){"
                    "       A[get_global_id(0)]=A[get_global_id(0)]*2;"
                    "   }";
    sources.push_back({kernel_code.c_str(),kernel_code.length()});

    cl::Program program(context,sources);
    if(program.build({default_device})!=CL_SUCCESS){
        std::cout<<" Error building: "<<program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(default_device)<<"\n";
        exit(1);
    }

    std::vector<int> v = {3, 1, 5, 6};

    cl::Buffer buffer_A(context,CL_MEM_READ_WRITE,sizeof(int)*v.size());
    cl::CommandQueue queue(context,default_device);

    if (queue.enqueueWriteBuffer(buffer_A,CL_TRUE,0,sizeof(int)*v.size(),v.data()) != CL_SUCCESS) {
        std::cout << "Failed to write memory;n";
        exit(1);
    }

    cl::Kernel kernel_add = cl::Kernel(program,"mul2");
    kernel_add.setArg(0,buffer_A);

    if (queue.enqueueNDRangeKernel(kernel_add,cl::NullRange,cl::NDRange(v.size()),cl::NullRange) != CL_SUCCESS) {
        std::cout << "Failed to enqueue kernel\n";
        exit(1);
    }

    if (queue.finish() != CL_SUCCESS) {
        std::cout << "Failed to finish kernel\n";
        exit(1);
    }

    if (queue.enqueueReadBuffer(buffer_A,CL_TRUE,0,sizeof(int)*v.size(),v.data()) != CL_SUCCESS) {
        std::cout << "Failed to read result\n";
        exit(1);
    }

    std::cout<<"result: \n";
    for (auto e : v) {
        std::cout<<e<<" ";
    }
}
{% endhighlight %}


There are currently two implementations of SYCL available; "triSYCL", an experimental open source version by Xilinx (mostly used as a testbed for the standard), and "ComputeCpp", an industry-strength implementation by Codeplay[^1] (currently in open Beta). We'll be using ComputeCpp in this post.



[^1]: I work for Codeplay, but this post was written in my own time with no suggestion from my employer.
