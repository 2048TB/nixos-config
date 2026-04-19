{ pkgs, ... }:
let
  cudaToolkit = pkgs.cudaPackages.cudatoolkit;
  cudaNvcc = pkgs.cudaPackages.cuda_nvcc;
  cudnn = pkgs.cudaPackages.cudnn;
  nccl = pkgs.cudaPackages.nccl;
in
{
  environment.systemPackages = [
    cudaToolkit
    cudaNvcc
    cudnn
    nccl
  ];

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
