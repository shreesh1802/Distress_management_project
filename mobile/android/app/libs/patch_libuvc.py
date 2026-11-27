"""Make libuvc's format negotiation tolerant of webcams that answer slightly differently.

Usage: python -I patch_libuvc.py <path to libuvc/src/stream.c>
"""
import sys

path = sys.argv[1]
s = open(path, encoding="utf-8").read()


def rep(s, old, new):
    assert s.count(old) == 1, "expected exactly one match for: " + old[:100]
    return s.replace(old, new, 1)


# 1. Frame rate: if no interval matches the requested fps exactly, use the closest one of the right size.
s = rep(s, """    uvc_streaming_interface_t *stream_if;

    /* find a matching frame descriptor and interval */
    DL_FOREACH(devh->info->stream_ifs, stream_if) {
        uvc_format_desc_t *format;

        DL_FOREACH(stream_if->format_descs, format) {
            uvc_frame_desc_t *frame;

            if (!_uvc_frame_format_matches_guid(cf, format->guidFormat))
                continue;

            DL_FOREACH(format->frame_descs, frame) {
                if (frame->wWidth != width || frame->wHeight != height)
                    continue;
""", """    uvc_streaming_interface_t *stream_if;
    /* closest frame rate of the right size, used when none matches exactly */
    uvc_streaming_interface_t *best_if = NULL;
    uvc_format_desc_t *best_format = NULL;
    uvc_frame_desc_t *best_frame = NULL;
    uint32_t best_interval = 0;
    int best_diff = 0x7fffffff;

    /* find a matching frame descriptor and interval */
    DL_FOREACH(devh->info->stream_ifs, stream_if) {
        uvc_format_desc_t *format;

        DL_FOREACH(stream_if->format_descs, format) {
            uvc_frame_desc_t *frame;

            if (!_uvc_frame_format_matches_guid(cf, format->guidFormat))
                continue;

            DL_FOREACH(format->frame_descs, frame) {
                if (frame->wWidth != width || frame->wHeight != height)
                    continue;

                if (frame->intervals) {
                    uint32_t *iv;
                    for (iv = frame->intervals; *iv; ++iv) {
                        int f = (int) (10000000 / *iv);
                        int d = f > fps ? f - fps : fps - f;
                        if (d < best_diff) {
                            best_diff = d;
                            best_if = stream_if;
                            best_format = format;
                            best_frame = frame;
                            best_interval = *iv;
                        }
                    }
                } else if (frame->dwDefaultFrameInterval && best_frame == NULL) {
                    best_if = stream_if;
                    best_format = format;
                    best_frame = frame;
                    best_interval = frame->dwDefaultFrameInterval;
                }
""")

s = rep(s, """    return UVC_ERROR_INVALID_MODE;

    found:
    return uvc_probe_stream_ctrl(devh, ctrl);
}

/** Get a negotiated still control block""", """    if (best_frame) {
        LOGW("no exact %dfps for %dx%d; using %u (100ns interval) instead", fps, width, height, best_interval);
        ctrl->bInterfaceNumber = best_if->bInterfaceNumber;
        uvc_claim_if(devh, ctrl->bInterfaceNumber);
        uvc_query_stream_ctrl(devh, ctrl, 1, UVC_GET_MAX);
        ctrl->bmHint = (1 << 0);
        ctrl->bFormatIndex = best_format->bFormatIndex;
        ctrl->bFrameIndex = best_frame->bFrameIndex;
        ctrl->dwFrameInterval = best_interval;
        goto found;
    }
    LOGE("no %dx%d frame of the requested format", width, height);
    return UVC_ERROR_INVALID_MODE;

    found:
    return uvc_probe_stream_ctrl(devh, ctrl);
}

/** Get a negotiated still control block""")

# 2. Negotiation: log what the webcam answered; accept it when it kept our format and size.
s = rep(s, """    uvc_stream_ctrl_t required_ctrl = *ctrl;

    uvc_query_stream_ctrl(devh, ctrl, 1, UVC_SET_CUR);
    uvc_query_stream_ctrl(devh, ctrl, 1, UVC_GET_CUR);

    if (!_uvc_stream_params_negotiated(&required_ctrl, ctrl)) {
        UVC_DEBUG("Unable to negotiate streaming format");
        return UVC_ERROR_INVALID_MODE;
    }

    return UVC_SUCCESS;""", """    uvc_stream_ctrl_t required_ctrl = *ctrl;

    int set_err = uvc_query_stream_ctrl(devh, ctrl, 1, UVC_SET_CUR);
    int get_err = uvc_query_stream_ctrl(devh, ctrl, 1, UVC_GET_CUR);

    if (_uvc_stream_params_negotiated(&required_ctrl, ctrl))
        return UVC_SUCCESS;

    LOGW("probe set=%d get=%d asked fmt=%d frame=%d interval=%u payload=%u; webcam fmt=%d frame=%d interval=%u payload=%u",
         set_err, get_err, required_ctrl.bFormatIndex, required_ctrl.bFrameIndex, required_ctrl.dwFrameInterval,
         required_ctrl.dwMaxPayloadTransferSize, ctrl->bFormatIndex, ctrl->bFrameIndex, ctrl->dwFrameInterval,
         ctrl->dwMaxPayloadTransferSize);

    /* The webcam kept our format and size but wants a different packet size: go with the webcam. */
    if (required_ctrl.bFormatIndex == ctrl->bFormatIndex && required_ctrl.bFrameIndex == ctrl->bFrameIndex)
        return UVC_SUCCESS;

    /* Ask again, this time leaving the packet size to the webcam. */
    *ctrl = required_ctrl;
    ctrl->dwMaxPayloadTransferSize = 0;
    ctrl->dwMaxVideoFrameSize = 0;
    set_err = uvc_query_stream_ctrl(devh, ctrl, 1, UVC_SET_CUR);
    get_err = uvc_query_stream_ctrl(devh, ctrl, 1, UVC_GET_CUR);
    if (required_ctrl.bFormatIndex == ctrl->bFormatIndex && required_ctrl.bFrameIndex == ctrl->bFrameIndex)
        return UVC_SUCCESS;

    LOGE("second probe set=%d get=%d webcam fmt=%d frame=%d interval=%u payload=%u",
         set_err, get_err, ctrl->bFormatIndex, ctrl->bFrameIndex, ctrl->dwFrameInterval,
         ctrl->dwMaxPayloadTransferSize);
    return UVC_ERROR_INVALID_MODE;""")

open(path, "w", encoding="utf-8").write(s)
print("patched")
