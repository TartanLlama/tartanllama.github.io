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

----------------------------

### Lightning intro to GPGPU

Before I get started on how to use SYCL, I'll give a brief outline of why you might want to run compute jobs on the GPU for those who are unfamiliar. I've you've already used OpenCL, CUDA or similar, feel free to skip.

The key difference between a GPU and a CPU is that, rather than having a small number of complex, powerful cores (1-8 for common consumer desktop hardware), a GPU has a huge number of small, simple processing elements.

![CPU architecture]({{site.url}}/assets/cpu.png)

Above is a comically simplified diagram of a CPU with four cores. Each core has a set of registers and is attached to various levels of cache (some might be shared, some not), and then main memory.

![GPU architecture]({{site.url}}/assets/gpu.png)

In the GPU, tiny processing elements are grouped into execution units. Each processing element has a bit of memory attached to it, and each execution unit has some memory shared between its processing elements. After that, there's some GPU-wide memory, then the same main memory which the CPU uses. The elements within an execution unit execute in *lockstep*, where each element executes the same instruction on a different piece of data.

There are many aspects of GPGPU programming which make it an entirely different beast to everyday CPU programming. For example, transferring data from main memory to the GPU is *slow*. *Really* slow. Like, kill all your performance and get you fired slow. The tradeoff with GPU programming, therefore is to make as much of the ridiculously high throughput of your accelerator to hide the latency of shipping the data to and from it.

There are other issues which might not be immediately apparent, like the cost of branching. Since the processing elements in an execution unit work in lockstep, nested branches which cause them to take different paths (divergent control flow) is a real problem. Most GPUs solve this by just executing all branches for all elements and masking out the unneeded results. That's an exponential explosion in complexity based on the level of nesting, which is A Bad Thing &trade;. Of course, there are optimizations which can aid this, but the idea stands: simple assumptions and knowledge you bring from the CPU world might cause you big problems in the GPU world.

Before we get back to SYCL, some short pieces of terminology. The *host* is the main CPU running on your machine which executes

--------------------------

### Back to SYCL

There are currently two implementations of SYCL available; "triSYCL", an experimental open source version by Xilinx (mostly used as a testbed for the standard), and "ComputeCpp", an industry-strength implementation by Codeplay[^1] (currently in open Beta). We'll be using ComputeCpp in this post.

Step 1 is to get ComputeCpp up and running on your machine. The main components are a runtime library which implements the SYCL API, and a Clang-based compiler which compiles both your host code and your device code. At the time of writing, Intel CPUs and some AMD GPUs are officially supported on Ubuntu and CentOS. It should be pretty easy to get it working on other Linux distributions (I got it running on my Arch system, for instance. Support for more hardware and operating systems are being worked on, so check the [supported platforms document](https://www.codeplay.com/products/computesuite/computecpp/reference/platform-support-notes) for an up-to-date list. The dependencies and components are listed [here](https://www.codeplay.com/products/computesuite/computecpp/reference/release-notes/). You might also want to download the [SDK](https://github.com/codeplaysoftware/computecpp-sdk), which contains samples, documentation, build system integration files, and more. I'll be using the [SYCL Parallel STL](https://github.com/KhronosGroup/SyclParallelSTL) in this post, so get that if you want to play along at home.



[^1]: I work for Codeplay, but this post was written in my own time with no suggestion from my employer.
