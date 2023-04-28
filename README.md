Experimenting with nix flake usage of [cargo-script-mvs](https://github.com/epage/cargo-script-mvs).

With nix flakes enabled, try this out:
```
$ nix run github:danjl1100/cargo-script-mvs-flake#script
```

Or, more interestingly,
```
$ nix build github:danjl1100/cargo-script-mvs-flake#script

$ ls result/bin
script  script-src

$ cat result/bin/script-src
#!/nix/store/hashhashhashhashhashhashhashhash-cargo-script-mvs-x.y.z/bin/cargo-eval
//! ```cargo
//! [dependencies]
//! rand = "0.8"
//! ```
fn main() {
  println!("your lucky number is {}", rand::random::<u16>());

  let mut args = std::env::args();
  if let Some(first) = args.next() {
    println!("\ncheck out the built binary location:");
    println!("\t{first}");
  }
}

$ cat result/bin/script
[shell script, setting path then calling script-src]
```
