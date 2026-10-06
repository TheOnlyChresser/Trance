//
//  VoiceCase.swift
//  Trance
//

/// Hvornår stemmen siger noget, og hvilke optagelser i Voice-mappen der hører til.
/// Faserne og deres dele står i den rækkefølge, de bruges i en session.
enum VoiceCase {
    // faserne
    case preparation
    case establishing(Establishing)
    case eyeFixation(EyeFixation)
    case eyeClosing(EyeClosing)
    case deepening(Deepening)
    case rest(Rest)
    case awakening(Awakening)

    // bruges undervejs, når målingerne ændrer sig
    case focus(Focus)
    case relaxation(Relaxation)
    case eyes(Eyes)

    /// Fase 1: punktet og åndedrættet.
    enum Establishing {
        /// forklarer punktet og åbner fasen
        case opening
        /// at se på punktet og følge dets rytme
        case theDot
        /// at mærke kroppen og falde til ro
        case settling
    }

    /// Fase 2: tunge øjne, fra synet der fortoner sig til øjne, der gerne vil lukke.
    enum EyeFixation {
        /// åbner fasen
        case opening
        /// alt omkring punktet bliver utydeligt
        case blurring
        /// øjenlågene bliver tungere
        case heavyEyelids
        /// øjnene vil gerne lukke
        case readyToClose
    }

    /// Fase 3: øjnene lukker.
    enum EyeClosing {
        /// åbner fasen
        case invitation
        /// mens øjnene stadig er åbne
        case encouragement
        /// tæller fra tre til et, hvis øjnene ikke er lukket endnu
        case countdown
        /// øjnene lukkede ikke i tide, og sessionen fortsætter med åbne øjne
        case stayingOpen
    }

    /// Fase 4: uddybning. En typisk rækkefølge er åndedræt, én nedtælling, kropsscanning og ét billede.
    enum Deepening {
        case breath
        /// tre forskellige nedtællinger; brug kun én
        case countdown
        /// oppefra og ned, fra øjnene til hele kroppen
        case bodyScan
        /// fire forskellige billeder; brug ét
        case imagery
        /// et trygt sted, fortalt over tre optagelser
        case safePlace
        /// korte fordybere til indimellem; kan også bruges i hvilefasen
        case deepener
    }

    /// Fase 5: hvile. Stilheden er det vigtigste.
    enum Rest {
        case resting
        /// når tankerne vandrer, og om tryghed
        case thoughts
        /// mini-genopfriskning ca. hvert 10. minut i lange sessioner
        case refresh
        /// til at tage med; hører til sidst i fasen
        case keepsake
    }

    /// Fase 6: opvågning.
    enum Awakening {
        /// inden der tælles op
        case gathering
        /// tæller fra et til fem; skal altid med
        case countUp
        /// når øjnene er åbne igen
        case arriving
    }

    enum Focus {
        /// blikket har forladt punktet
        case wandering
        /// blikket er tilbage på punktet
        case returned
        /// blikket har været roligt på punktet længe
        case steady
        /// blikket bliver ved med at vandre; foreslår at lukke øjnene
        case keepsWandering
    }

    enum Relaxation {
        /// bekræfter en forandring, så de må kun bruges, når målingen viser den
        case rising
        /// står stille; skifter teknik
        case stalled
        case falling
    }

    enum Eyes {
        case closed
        /// øjnene har åbnet sig igen, efter de var lukket
        case reopened
    }

    /// Optagelserne til VoicePlayer, i den rækkefølge de passer bedst.
    var files: [String] {
        switch self {
        case .preparation: ["P01", "P02"]

        case .establishing(.opening): ["E01"]
        case .establishing(.theDot): ["E02", "E03", "E04", "E05", "E07", "E12", "E13", "E15"]
        case .establishing(.settling): ["E08", "E09", "E14", "E16"]

        case .eyeFixation(.opening): ["X01"]
        case .eyeFixation(.blurring): ["X02", "X05"]
        case .eyeFixation(.heavyEyelids):
            ["X06", "X07", "X08", "X09", "X10", "X11", "X12", "X13", "X14", "X15", "X17", "X18"]
        case .eyeFixation(.readyToClose): ["X19", "X20"]

        case .eyeClosing(.invitation): ["L01"]
        case .eyeClosing(.encouragement): ["L02", "L03", "L05", "L06", "L09", "L10"]
        case .eyeClosing(.countdown): ["L07"]
        case .eyeClosing(.stayingOpen): ["L11", "L12"]

        case .deepening(.breath): ["DA01", "DA02", "DA03", "DA06", "DA07"]
        case .deepening(.countdown): ["DN01", "DN02", "DN03"]
        case .deepening(.bodyScan):
            ["DK02", "DK03", "DK05", "DK06", "DK07", "DK08", "DK09", "DK10", "DK11", "DK12", "DK13", "DK14", "DK15"]
        case .deepening(.imagery): ["DB01", "DB02", "DB03", "DB04"]
        case .deepening(.safePlace): ["DB05", "DB06", "DB07"]
        case .deepening(.deepener): ["DF01", "DF02", "DF03", "DF05", "DF06", "DF08"]

        case .rest(.resting): ["H01", "H02", "H03", "H05", "H09", "H10", "H13", "H15", "H17", "H20"]
        case .rest(.thoughts): ["HT01", "HT02", "HT03", "HT04", "HT05"]
        case .rest(.refresh): ["HG01", "HG02", "HG03", "HG04"]
        case .rest(.keepsake): ["HM01", "HM02", "HM03", "HM04"]

        case .awakening(.gathering): ["O01"]
        case .awakening(.countUp): ["O02", "O03"]
        case .awakening(.arriving): ["O04", "O05", "O08"]

        case .focus(.wandering): ["FV01", "FV02", "FV04", "FV05"]
        case .focus(.returned): ["FT02", "FT03", "FT04"]
        case .focus(.steady): ["FS03"]
        case .focus(.keepsWandering): ["FG01", "FG02"]

        case .relaxation(.rising): ["AS01", "AS03", "AS04"]
        case .relaxation(.stalled): ["AN02", "AN03", "AN06", "AN07"]
        case .relaxation(.falling): ["AF01", "AF04", "AF05", "AF06"]

        case .eyes(.closed): ["ØL01", "ØL02"]
        case .eyes(.reopened): ["ØÅ01", "ØÅ02"]
        }
    }

    /// Om optagelserne hører sammen og skal siges alle sammen i den rækkefølge, de står i.
    /// Ellers er de en pulje, man vælger fra.
    var isSequence: Bool {
        switch self {
        case .preparation, .deepening(.bodyScan), .deepening(.safePlace), .rest(.refresh),
             .awakening(.countUp), .awakening(.arriving):
            true
        default:
            false
        }
    }
}
