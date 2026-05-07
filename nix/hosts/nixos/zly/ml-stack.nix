{ pkgs, ... }:
let
  cudaToolkit = pkgs.cudaPackages.cudatoolkit;
  cudaNvcc = pkgs.cudaPackages.cuda_nvcc;
  inherit (pkgs.cudaPackages) cudnn nccl;
  unstableOllamaCuda = pkgs.unstable.ollama-cuda;
in
{
  environment.systemPackages = [
    cudaToolkit
    cudaNvcc
    cudnn
    nccl
    unstableOllamaCuda
  ];

  services.ollama = {
    enable = true;
    package = unstableOllamaCuda;
  };

  environment.variables = {
    CUDA_PATH = cudaToolkit;
    CUDA_HOME = cudaToolkit;
    CUDA_ROOT = cudaToolkit;
    CUDNN_PATH = cudnn;
    CUDNN_INCLUDE_DIR = "${cudnn}/include";
    CUDNN_LIB_DIR = "${cudnn}/lib";
    NCCL_ROOT_DIR = nccl;
    NCCL_LIB_DIR = "${nccl}/lib";
  };
}
