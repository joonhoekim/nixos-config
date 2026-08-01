{
    "profiles": [
        {
            "complex_modifications": {
                "rules": [
                    {
                        "description": "Vim/Neovim Navigation Mode [Caps Lock as Trigger Key] (rev 3, parked)",
                        "manipulators": [
                            {
                                "from": {
                                    "key_code": "caps_lock",
                                    "modifiers": { "optional": ["caps_lock"] }
                                },
                                "to": [
                                    {
                                        "set_variable": {
                                            "name": "touchcursor_mode",
                                            "value": 1
                                        }
                                    }
                                ],
                                "to_after_key_up": [
                                    {
                                        "set_variable": {
                                            "name": "touchcursor_mode",
                                            "value": 0
                                        }
                                    }
                                ],
                                "to_if_alone": [{ "key_code": "caps_lock" }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "h", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "left_arrow" }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "j", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "down_arrow" }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "k", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "up_arrow" }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "l", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "right_arrow" }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "w", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "right_arrow", "modifiers": ["option"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "e", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "right_arrow", "modifiers": ["option"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "b", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "left_arrow", "modifiers": ["option"] }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "0", "modifiers": { "optional": ["any"] } },
                                "to": [{ "key_code": "left_arrow", "modifiers": ["command"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": {
                                    "key_code": "4",
                                    "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
                                },
                                "to": [{ "key_code": "right_arrow", "modifiers": ["command"] }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": {
                                    "key_code": "open_bracket",
                                    "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
                                },
                                "to": [{ "key_code": "up_arrow", "modifiers": ["option"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": {
                                    "key_code": "close_bracket",
                                    "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
                                },
                                "to": [{ "key_code": "down_arrow", "modifiers": ["option"] }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": {
                                    "key_code": "g",
                                    "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
                                },
                                "to": [{ "key_code": "down_arrow", "modifiers": ["command"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "g", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "up_arrow", "modifiers": ["command"] }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": {
                                    "key_code": "n",
                                    "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
                                },
                                "to": [{ "key_code": "g", "modifiers": ["command", "shift"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "n", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "g", "modifiers": ["command"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "slash", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "f", "modifiers": ["command"] }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "u", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "z", "modifiers": ["command"] }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": {
                                    "key_code": "x",
                                    "modifiers": { "mandatory": ["shift"], "optional": ["caps_lock"] }
                                },
                                "to": [{ "key_code": "delete_or_backspace" }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "x", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "delete_forward" }],
                                "type": "basic"
                            },

                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "y", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "c", "modifiers": ["command"] }],
                                "type": "basic"
                            },
                            {
                                "conditions": [
                                    { "name": "touchcursor_mode", "type": "variable_if", "value": 1 }
                                ],
                                "from": { "key_code": "p", "modifiers": { "optional": ["caps_lock"] } },
                                "to": [{ "key_code": "v", "modifiers": ["command"] }],
                                "type": "basic"
                            }
                        ]
                    },
                    {
                        "description": "Change Won (₩) to grave accent (`) in Korean layout.",
                        "manipulators": [
                            {
                                "conditions": [
                                    {
                                        "input_sources": [{ "language": "ko" }],
                                        "type": "input_source_if"
                                    }
                                ],
                                "from": {
                                    "key_code": "grave_accent_and_tilde",
                                    "modifiers": { "optional": ["any"] }
                                },
                                "to": [
                                    {
                                        "key_code": "grave_accent_and_tilde",
                                        "modifiers": ["option"]
                                    }
                                ],
                                "type": "basic"
                            }
                        ]
                    }
                ]
            },
            "name": "Default profile",
            "selected": true,
            "simple_modifications": [
                {
                    "from": { "key_code": "right_command" },
                    "to": [{ "key_code": "f18" }]
                }
            ],
            "virtual_hid_keyboard": { "keyboard_type_v2": "ansi" }
        }
    ]
}
