#include <algorithm>
#include <cstdio>

#include "alpakaConfig.h"
#include "analyzer_alpaka.h"
#include "input.h"
#include "output.h"
#include "pixelgpudetails.h"
#include "rawtodigi_alpaka.h"

namespace {
  constexpr int NLOOPS = 100;
}

namespace Alpaka {

  namespace ALPAKA_ARCHITECTURE {

    void analyze(Input const& input) {
      DevHost const devHost(alpaka::pltf::getDevByIdx<PltfHost>(0u));
      DevAcc const devAcc(alpaka::pltf::getDevByIdx<PltfAcc>(0u));
      Idx const elements(1);
      Vec const extent(elements);

      Queue queue(devAcc);

      int totaltime = 0;

      std::unique_ptr<Output> output;

      for (int i = 0; i < NLOOPS; i++) {
        output = std::make_unique<Output>();

        using ViewInput = alpaka::mem::view::ViewPlainPtr<DevHost, const Input, Dim, Idx>;
        ViewInput input_hBuf(&input, devHost, extent);

        using BufDevInput = alpaka::mem::buf::Buf<DevAcc, Input, Dim, Idx>;
        BufDevInput input_dBuf(alpaka::mem::buf::alloc<Input, Idx>(devAcc, extent));

        using ViewOutput = alpaka::mem::view::ViewPlainPtr<DevHost, Output, Dim, Idx>;
        ViewOutput output_hBuf(output.get(), devHost, extent);

        using BufDevOutput = alpaka::mem::buf::Buf<DevAcc, Output, Dim, Idx>;
        BufDevOutput output_dBuf(alpaka::mem::buf::alloc<Output, Idx>(devAcc, extent));

        auto start = std::chrono::high_resolution_clock::now();

        alpaka::mem::view::copy(queue, input_dBuf, input_hBuf, extent);

        rawtodigi(alpaka::mem::view::getPtrNative(input_dBuf),
                  alpaka::mem::view::getPtrNative(output_dBuf),
                  input.wordCounter,
                  true,
                  true,
                  true,
                  queue);

        alpaka::mem::view::copy(queue, output_hBuf, output_dBuf, extent);

        alpaka::wait::wait(queue);

        auto stop = std::chrono::high_resolution_clock::now();

        auto diff = stop - start;
        auto time = std::chrono::duration_cast<std::chrono::microseconds>(diff).count();
        totaltime += time;
      }

      std::cout << "Output: " << countModules(output->moduleInd, input.wordCounter) << " modules in "
                << (static_cast<double>(totaltime) / NLOOPS) << " us" << std::endl;
    }

  }  // namespace ALPAKA_ARCHITECTURE

}  // namespace Alpaka
