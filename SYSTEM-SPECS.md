# System Specifications

## Machine: wsu (System76 Thelio Mega)

| Component | Details |
|-----------|---------|
| **Hostname** | jgi-ont |
| **OS** | Ubuntu 22.04.5 LTS |
| **Kernel** | 6.12.10-76061203-generic |
| **Chassis** | Desktop |
| **Vendor** | System76 |
| **Model** | Thelio Mega |

### CPU
| Property | Value |
|----------|-------|
| Model | AMD Ryzen Threadripper PRO 5975WX |
| Cores | 32 |
| Threads | 64 |
| Architecture | x86_64 |

### Memory
| Property | Value |
|----------|-------|
| Total RAM | 256 GB (251 GiB usable) |
| Type | DDR4 (platform typical) |

### Storage
| Device | Size | Model |
|--------|------|-------|
| nvme0n1 | 3.6 TB | CT4000P3PSSD8 |
| sda | 9.1 TB | Expansion HDD |
| sdb | 27.3 TB | ST30000NT011-3V2103 |
| sdc | 27.3 TB | ST30000NT011-3V2103 |

### Graphics
| Property | Value |
|----------|-------|
| GPU 0 | NVIDIA RTX PRO 6000 Blackwell Max-Q Workstation Edition |
| GPU 1 | NVIDIA RTX A6000 |
| GPU 2 | NVIDIA RTX PRO 6000 Blackwell Max-Q Workstation Edition |
| Driver | NVIDIA 580.95.05 |
| CUDA | 13.0 |

### Monitoring
- **CPU (64 threads)**: `btop` with per-core view (see `configs/btop/btop.conf`).
- **GPU (3 devices)**: `nvtop` for per-GPU utilization + memory.
- **CLI quick checks**: `nvidia-smi -L`, `watch -n 1 nvidia-smi`.

### Special Configurations
- **Multi-GPU**: CUDA workloads pin via `CUDA_VISIBLE_DEVICES`.
- **Driver Management**: `ubuntu-drivers devices` shows recommended driver stack.
- **Desktop**: GNOME on Xorg.

---
*Generated: 2026-01-04*
