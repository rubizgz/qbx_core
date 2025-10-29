---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'Civil',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Desempleado',
                payment = 1
            },
        },
    },
    ['police'] = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Oficial',
                payment = 7
            },
            [2] = {
                name = 'Sargento',
                payment = 10
            },
            [3] = {
                name = 'Teniente',
                payment = 12
            },
            [4] = {
                name = 'Jefe',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['bcso'] = {
        label = 'BCSO',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Oficial',
                payment = 7
            },
            [2] = {
                name = 'Sargento',
                payment = 10
            },
            [3] = {
                name = 'Teniente',
                payment = 12
            },
            [4] = {
                name = 'Jefe',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['sasp'] = {
        label = 'SASP',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Oficial',
                payment = 7
            },
            [2] = {
                name = 'Sargento',
                payment = 10
            },
            [3] = {
                name = 'Teniente',
                payment = 12
            },
            [4] = {
                name = 'Jefe',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['ambulance'] = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Paramédico',
                payment = 7
            },
            [2] = {
                name = 'Doctor',
                payment = 10
            },
            [3] = {
                name = 'Cirujano',
                payment = 12
            },
            [4] = {
                name = 'Jefe',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['realestate'] = {
        label = 'Bienes raíces',
        type = 'realestate',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Ventas de casas',
                payment = 7
            },
            [2] = {
                name = 'Ventas comerciales',
                payment = 10
            },
            [3] = {
                name = 'Negociador',
                payment = 12
            },
            [4] = {
                name = 'Gerente',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['taxi'] = {
        label = 'Taxista',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Conductor',
                payment = 7
            },
            [2] = {
                name = 'Conductor de eventos',
                payment = 10
            },
            [3] = {
                name = 'Ventas',
                payment = 12
            },
            [4] = {
                name = 'Gerente',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['bus'] = {
        label = 'Autobusero',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Conductor',
                payment = 5
            },
        },
    },
    ['cardealer'] = {
        label = 'Concesionario',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Ventas de sala de exposición',
                payment = 7
            },
            [2] = {
                name = 'Ventas comerciales',
                payment = 10
            },
            [3] = {
                name = 'Finanzas',
                payment = 12
            },
            [4] = {
                name = 'Gerente',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['mechanic'] = {
        label = 'Mecánico',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recluta',
                payment = 5
            },
            [1] = {
                name = 'Novato',
                payment = 7
            },
            [2] = {
                name = 'Experimentado',
                payment = 10
            },
            [3] = {
                name = 'Avanzado',
                payment = 12
            },
            [4] = {
                name = 'Gerente',
                isboss = true,
                bankAuth = true,
                payment = 15
            },
        },
    },
    ['judge'] = {
        label = 'Honorario',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Juez',
                payment = 10
            },
        },
    },
    ['lawyer'] = {
        label = 'Bufete de abogados',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Asociado',
                payment = 5
            },
        },
    },
    ['reporter'] = {
        label = 'Reportero',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Periodista',
                payment = 5
            },
        },
    },
    ['trucker'] = {
        label = 'Camionero',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Conductor',
                payment = 5
            },
        },
    },
    ['tow'] = {
        label = 'Gruista',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Conductor',
                payment = 5
            },
        },
    },
    ['garbage'] = {
        label = 'Basurero',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recogedor',
                payment = 5
            },
        },
    },
    ['vineyard'] = {
        label = 'Viñedo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recogedor',
                payment = 5
            },
        },
    },
    ['miner'] = {
        label = 'Minero',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recogedor',
                payment = 7
            },
        },
    },
    ['hotdog'] = {
        label = 'Perritos Calientes',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Ventas',
                payment = 5
            },
        },
    },
}