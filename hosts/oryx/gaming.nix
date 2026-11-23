{
  ...
}:

{
  # Intel thermal management for sustained gaming workloads.
  services.thermald.enable = true;

  # Keep the NVIDIA driver resident and retain the existing PRIME sync power posture.
  hardware.nvidia = {
    nvidiaPersistenced = true;
    powerManagement.enable = true;
  };

  # Provide additional shader-cache headroom for repeated game launches.
  environment.sessionVariables = {
    __GL_SHADER_DISK_CACHE_SIZE = "10737418240";
  };
}
