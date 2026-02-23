_base_ = ['./dbnet_resnet18_fpnc_1200e_icdar2015.py']

# quick_run dataset path override
icdar2015_textdet_train = _base_.icdar2015_textdet_train
icdar2015_textdet_train.data_root = 'data/mini_icdar2015'
icdar2015_textdet_test = _base_.icdar2015_textdet_test
icdar2015_textdet_test.data_root = 'data/mini_icdar2015'

# Save checkpoints every 10 epochs, and only keep the latest checkpoint
default_hooks = dict(
    checkpoint=dict(
        type='CheckpointHook',
        interval=10,
        max_keep_ckpts=1,
    ))

# Set the maximum number of epochs to 400, and validate the model every 10 epochs
train_cfg = dict(type='EpochBasedTrainLoop', max_epochs=400, val_interval=10)

# Fix learning rate as a constant
param_scheduler = [
    dict(type='ConstantLR', factor=1.0),
]

# Windows-friendly dataloader settings (avoid worker spawn/persistent issues)
train_dataloader = dict(
    batch_size=8,
    num_workers=0,
    persistent_workers=False,
    dataset=icdar2015_textdet_train)

val_dataloader = dict(
    batch_size=1,
    num_workers=0,
    persistent_workers=False,
    dataset=icdar2015_textdet_test)

test_dataloader = val_dataloader

# Match the effective batch size used above
auto_scale_lr = dict(base_batch_size=8)

