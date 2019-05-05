# From https://github.com/ipython/ipython/blob/master/IPython/lib/security.py
# Modified to remain compatibility while not depending on iPython modules
def hash_pass(passphrase):
    import hashlib
    import random
    h = hashlib.new("sha1")
    salt = ("%0" + str(12) + "x") % random.getrandbits(4 * 12)
    h.update(passphrase.encode("utf-8") + salt.encode("ascii"))
    return  ":".join(("sha1", salt, h.hexdigest()))