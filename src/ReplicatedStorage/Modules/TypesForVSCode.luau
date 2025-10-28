export type CustomUI_ColorPicker = Frame & {
    AllColors: CanvasGroup & {
        ErrorFrame: Frame & {
            Error: TextLabel,
        },
        Scroller: ScrollingFrame & {
            ColorTemp: ImageButton & {
                UICorner: UICorner,
            },
            UIGridLayout: UIGridLayout,
            UIPadding: UIPadding,
        },
        UICorner: UICorner,
    },
    SaveOrUseChoose: Frame & {
        SaveNew: Frame,
        UIListLayout: UIListLayout,
        Use: Frame,
    },
    SavedColors: CanvasGroup & {
        Colors: Frame & {
            ["1"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["2"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["3"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["4"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["5"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["6"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["7"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["8"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["9"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            ["10"]: ImageButton & {
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
            },
            UIListLayout: UIListLayout,
            UIPadding: UIPadding,
        },
        Disabled: Frame & {
            msg: TextLabel,
        },
        UICorner: UICorner,
    },
    Title: TextLabel,
    TotalSaved: TextLabel,
    saveEtc: Frame & {
        ButtonMount: Frame,
        Color: Frame & {
            Colors: CanvasGroup & {
                New: Frame,
                Old: Frame,
                UIAspectRatioConstraint: UIAspectRatioConstraint,
                UICorner: UICorner,
                UIListLayout: UIListLayout,
            },
            UIListLayout2: UIListLayout,
            colorTitle: TextLabel,
        },
        ColorCode: Frame & {
            Code: Frame & {
                Hex: Frame & {
                    HashTag: TextLabel,
                    TextBox: TextBox & {
                        UICorner: UICorner,
                        UIStroke: UIStroke,
                    },
                    UIListLayout1: UIListLayout,
                },
                SizeToggle: TextButton & {
                    UIAspectRatioConstraint: UIAspectRatioConstraint,
                    UICorner: UICorner,
                },
            },
            Disabled: Frame & {
                msg: TextLabel,
            },
        },
        UIListLayout: UIListLayout,
    },
    savedTitle: TextLabel,
}

export type CustomUI_TextButton = Frame & {
    ErrorTrigger: TextButton & {
        TextButton: TextButton,
    },
}

local types = {}
return types