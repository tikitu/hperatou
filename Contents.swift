/// ### Randomness stuff stolen from https://www.pointfree.co/episodes/ep47-predictable-randomness-part-1

struct AnyRandomNumberGenerator: RandomNumberGenerator {
  var rng: RandomNumberGenerator
  mutating func next() -> UInt64 {
    return rng.next()
  }
}

struct Gen<A> {
  let run: (inout AnyRandomNumberGenerator) -> A

  func run<RNG: RandomNumberGenerator>(using rng: inout RNG) -> A {
    var arng = AnyRandomNumberGenerator(rng: rng)
    let result = self.run(&arng)
    rng = arng.rng as! RNG
    return result
  }
}


extension Gen {
  func map<B>(_ f: @escaping (A) -> B) -> Gen<B> {
    return Gen<B> { rng in f(self.run(&rng)) }
  }
}

extension Gen where A: BinaryFloatingPoint, A.RawSignificand: FixedWidthInteger {
  static func float(in range: ClosedRange<A>) -> Gen {
  //  return uniform.map { t in
  //    t * (range.upperBound - range.lowerBound) + range.lowerBound
  //  }
    return Gen { rng in .random(in: range, using: &rng) }
  }
}

extension Gen where A: FixedWidthInteger {
    static func int(in range: ClosedRange<A>) -> Gen {
        return Gen { rng in .random(in: range, using: &rng) }
    }
}

extension Gen where A == Bool {
  static let bool = Gen { rng in .random(using: &rng) }
}


extension Gen {
  static func element(of xs: [A]) -> Gen<A?> {
    return Gen<A?> { rng in xs.randomElement(using: &rng) }
  }
}

extension Gen {
  func flatMap<B>(_ f: @escaping (A) -> Gen<B>) -> Gen<B> {
    return Gen<B> { rng in
      let a = self.run(&rng)
      let genB = f(a)
      let b = genB.run(&rng)
      return b
    }
  }
}

extension Gen {
  func array(of count: Gen<Int>) -> Gen<[A]> {
    return count.flatMap { count in
      Gen<[A]> { rng -> [A] in
        var array: [A] = []
        for _ in 1...count {
          array.append(self.run(&rng))
        }
        return array
      }
    }
  }
}

extension Gen {
  static func always(_ a: A) -> Gen<A> {
    return Gen { _ in a }
  }
}

func zip<A, B>(_ ga: Gen<A>, _ gb: Gen<B>) -> Gen<(A, B)> {
  return Gen<(A, B)> { rng in
    (ga.run(&rng), gb.run(&rng))
  }
}

func zip<A, B, C>(with f: @escaping (A, B) -> C) -> (Gen<A>, Gen<B>) -> Gen<C> {
  return { zip($0, $1).map(f) }
}

func zip3<A, B, C, Z>(
  with f: @escaping (A, B, C) -> Z
  ) -> (Gen<A>, Gen<B>, Gen<C>) -> Gen<Z> {

  return { a, b, c in
    Gen<Z> { rng in
      f(a.run(&rng), b.run(&rng), c.run(&rng)) }
  }
}

func zip4<A, B, C, D, Z>(
  with f: @escaping (A, B, C, D) -> Z
  ) -> (Gen<A>, Gen<B>, Gen<C>, Gen<D>) -> Gen<Z> {

  return { a, b, c, d in
    Gen<Z> { rng in
      f(a.run(&rng), b.run(&rng), c.run(&rng), d.run(&rng)) }
  }
}

func zip9<A, B, C, D, E, F, G, H, I, Z>(
    with fun: @escaping (A, B, C, D, E, F, G, H, I) -> Z
    ) -> (Gen<A>, Gen<B>, Gen<C>, Gen<D>, Gen<E>, Gen<F>, Gen<G>, Gen<H>, Gen<I>) -> Gen<Z> {
    return { a, b, c, d, e, f, g, h, i in
        Gen<Z> { rng in
            fun(a.run(&rng), b.run(&rng), c.run(&rng), d.run(&rng), e.run(&rng),
                f.run(&rng), g.run(&rng), h.run(&rng), i.run(&rng))
        }
    }
}

struct LCRNG: RandomNumberGenerator {
  var seed: UInt64

  init(seed: UInt64) {
    self.seed = seed
  }

  mutating func next() -> UInt64 {
    seed = 2862933555777941757 &* seed &+ 3037000493
    return seed
  }
}

struct Environment {
  var rng = AnyRandomNumberGenerator(rng: SystemRandomNumberGenerator())
}
var Current = Environment()

Current.rng = AnyRandomNumberGenerator(rng: LCRNG(seed: 0))

/// # Aliens start here!

struct Alien {
    var name: String
    var cleverness: Int // (1-10)
    var power: Int // (1-10)
    var friendliness: Int // (1-10)
    var anthropomorphism: Int // (1-10)
    var technology: Int // (1-10)
    var communicationCapabilities: Int // (1-10)
    var distanceToEarth: Int // lightyears
    var maximumAge: Int // (in years)
}


let vowel = Gen<String>.element(of: ["a", "e", "i", "o", "u", "y"])
    .map { $0 ?? "" }
let consonant = Gen<String>.element(of: ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m",
                                          "n", "p", "q", "r", "s", "t", "v", "w", "x", "z"])
    .map { $0 ?? "" }
let syllable: Gen<String> = Gen<Int>.int(in: 1...4).flatMap {
    switch $0 {
    case 1:
        return vowel
    case 2:
        return zip(vowel, consonant).map { $0.0 + $0.1 }
    case 3:
        return zip(consonant, vowel).map { $0.0 + $0.1 }
    case 4:
        return zip3 { $0 + $1 + $2 } (consonant, vowel, consonant)
    default: // never happens
        return Gen<String>.always("")
    }
}
let name: Gen<String> = syllable.array(of: .int(in: 2...7)).map { $0.joined() }

let ten = Gen<Int>.element(of: Array(1...10) + Array(2...8) + Array(4...6)).map { $0 ?? 0 }
func exponential(digits: Int) -> Gen<Int> {
    Gen<Int>.int(in: 1...9)
        .array(of: Gen<Int>.int(in: 1...digits))
        .map { $0.reduce(0) { $0 * 10 + $1 }}
}

let alien: Gen<Alien> = zip9(with: Alien.init) (name,
                                                ten, ten, ten, ten, ten, ten,
                                                exponential(digits: 8), exponential(digits: 5))

let aliens = alien.array(of: .always(40)).run(using: &Current.rng)
let dump = (["Name, cleverness, power, friendliness, anthropomorphism, technology, communication capabilities, distance to Earth (lightyears), maximum age"]
    + aliens.map { "\($0.name), \($0.cleverness), \($0.power), \($0.friendliness), \($0.anthropomorphism), \($0.technology), \($0.communicationCapabilities), \($0.distanceToEarth), \($0.maximumAge)" })
    .joined(separator: "\n")
print(dump)
