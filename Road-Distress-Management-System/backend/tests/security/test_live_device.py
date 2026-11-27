"""
Live detection on a GPU: which device is picked, when float16 is used, and that the CPU path is unchanged.
No real model is loaded and no GPU is needed -- CUDA availability is simulated.
"""

import numpy as np
import pytest
import torch

from app.services.live import yolox_engine as engine


@pytest.fixture()
def gpus(monkeypatch):
    """Pretend this machine has the given number of CUDA GPUs."""

    def _set(count):
        monkeypatch.setattr(engine.torch.cuda, "is_available", lambda: count > 0)
        monkeypatch.setattr(engine.torch.cuda, "device_count", lambda: count)

    return _set


@pytest.mark.parametrize("requested", [None, "", "auto", " AUTO "])
def test_auto_uses_the_gpu_only_when_there_is_one(gpus, requested):
    gpus(0)
    assert engine.pick_device(requested).type == "cpu"
    gpus(1)
    assert engine.pick_device(requested).type == "cuda"


def test_asking_for_a_gpu_that_is_not_there_falls_back_to_the_cpu(gpus):
    gpus(0)
    assert engine.pick_device("cuda").type == "cpu"
    assert engine.pick_device("cuda:1").type == "cpu"


def test_a_gpu_number_that_does_not_exist_uses_the_first_gpu(gpus):
    gpus(1)
    assert engine.pick_device("cuda:3") == torch.device("cuda:0")
    gpus(2)
    assert engine.pick_device("cuda:1") == torch.device("cuda:1")


def test_cpu_and_unknown_values_run_on_the_cpu(gpus):
    gpus(1)
    assert engine.pick_device("cpu").type == "cpu"
    assert engine.pick_device("tpu").type == "cpu"


def test_half_precision_only_on_a_gpu():
    cpu, gpu = torch.device("cpu"), torch.device("cuda")
    for requested in (None, "auto", "true", "false"):
        assert engine.use_half_precision(requested, cpu) is False
    assert engine.use_half_precision("auto", gpu) is True
    assert engine.use_half_precision(None, gpu) is True
    assert engine.use_half_precision("false", gpu) is False
    assert engine.use_half_precision("off", gpu) is False


class _Exp:
    test_size = (64, 64)
    num_classes = 2
    test_conf = 0.3
    nmsthre = 0.45


def _detector(monkeypatch, outputs, seen):
    """A YOLOXDetector without a real model: records what the model receives, returns fixed outputs."""
    det = object.__new__(engine.YOLOXDetector)
    det.exp = _Exp()
    det.model_source = "road"
    det.conf_thresh = 0.3
    det.class_names = ["pothole", "crack"]
    det.device = torch.device("cpu")
    det.half = False
    det.preproc = lambda frame, _, size: (np.zeros((3, size[0], size[1]), dtype=np.float32), None)
    det.model = lambda img: seen.append((img.dtype, img.device.type)) or img
    monkeypatch.setattr(engine, "postprocess", lambda *a, **k: [outputs])
    return det


def test_the_cpu_path_still_feeds_float32_and_decodes_boxes(monkeypatch):
    seen = []
    row = torch.tensor([[10.0, 20.0, 30.0, 40.0, 0.9, 0.8, 1.0]])
    det = _detector(monkeypatch, row, seen)
    found = det.detect(np.zeros((64, 64, 3), dtype=np.uint8))
    assert seen == [(torch.float32, "cpu")]
    assert len(found) == 1 and found[0]["class_name"] == "crack"
    assert found[0]["box"] == [10.0, 20.0, 30.0, 40.0]
    assert abs(found[0]["confidence"] - 0.72) < 1e-6
    assert det.device_label == "cpu"


def test_float16_results_come_back_as_ordinary_numbers(monkeypatch):
    """What a GPU in float16 returns (half-precision rows) is decoded the same way."""
    seen = []
    row = torch.tensor([[10.0, 20.0, 30.0, 40.0, 0.9, 0.8, 0.0]], dtype=torch.float16)
    det = _detector(monkeypatch, row, seen)
    det.half = True
    found = det.detect(np.zeros((64, 64, 3), dtype=np.uint8))
    assert seen == [(torch.float16, "cpu")]
    assert isinstance(found[0]["confidence"], float) and found[0]["class_name"] == "pothole"


def test_nothing_found_is_an_empty_list(monkeypatch):
    det = _detector(monkeypatch, None, [])
    assert det.detect(np.zeros((64, 64, 3), dtype=np.uint8)) == []
