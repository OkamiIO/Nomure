#[macro_use]
extern crate rustler;
#[macro_use]
extern crate lazy_static;
extern crate igo;
extern crate rust_stemmers;
extern crate stopwords;
extern crate unic;

use igo::Tagger;
use std::collections::HashSet;
use std::path::PathBuf;
use stopwords::{Language, Stopwords, NLTK};
use unic::normal::StrNormalForm;
use unic::segment::Words;
use unic::ucd::common::is_alphanumeric;

use rustler::{Encoder, Env, NifResult, Term};

use rust_stemmers::{Algorithm, Stemmer};

lazy_static! {
    static ref TAGGER: igo::Tagger = {
        let dic_dir = PathBuf::from("data/ipadic");
        Tagger::new(&dic_dir).unwrap()
    };
}

mod atoms {
    rustler_atoms! {
        atom ok;
        //atom error;
        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

rustler_export_nifs! {
    "Elixir.Nomure.Native",
    [("tokenize", 2, tokenize)],
    None
}

fn tokenize<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let text: &str = try!(args[0].decode());
    // TODO: Do we use `whatlang` in order to know the language?
    // TODO: if we do not use whatlang then user must give the lang
    let is_cjk: bool = try!(args[1].decode());

    let stops: HashSet<_> = NLTK::stopwords(Language::Spanish)
        .unwrap()
        .iter()
        .map(|x| x.to_lowercase().nfkc().to_string())
        .collect();

    let stemmer = Stemmer::create(Algorithm::Spanish);

    // tokenize string
    let tokens = if is_cjk {
        TAGGER
            .parse(text)
            .iter()
            .map(|x| x.surface)
            // get words only
            .filter(|s: &&str| s.chars().any(is_alphanumeric))
            // lowercase and normalize
            .map(|x| x.to_lowercase().nfkc().to_string())
            // stop words removal
            .filter(|s| !stops.contains(s))
            // we do not stemm cjk atm
            .collect::<Vec<_>>()
    } else {
        Words::new(text, |s: &&str| s.chars().any(is_alphanumeric))
            // lowercase and normalize
            .map(|x| x.to_lowercase().nfkc().to_string())
            // stop words removal
            .filter(|s| !stops.contains(s))
            // stemm the tokens, it requires the actual string on lowercase and normalized
            .map(|x| stemmer.stem(&x).into_owned())
            .collect::<Vec<_>>()
    };

    Ok(tokens.encode(env))
}
